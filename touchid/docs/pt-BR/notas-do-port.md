# Notas do port: o que foi preciso adaptar

O [T1Bridge](https://github.com/standardagents/t1bridge) já fazia o Touch ID
e a Touch Bar dos MacBook Pro com chip T1 funcionarem, mas só tinha pacotes
para Arch Linux. Este port leva o mesmo código para **Fedora 45**,
**Debian 13** e **Ubuntu 26.04**. Abaixo estão os problemas que só
apareceram fora do Arch, na ordem em que foram encontrados num
`MacBookPro14,2` com Fedora 45.

## 1. O T1 tem três "modos" USB, e só um tem o Touch ID

O iBridge (`05ac:8600`) tem três configurações USB, e só uma fica ativa por
vez:

| Config. | O que expõe | Quem usa |
| --- | --- | --- |
| 1 | HID da Touch Bar. O próprio T1 desenha as teclas | drivers antigos (`apple-ibridge`, `apple-ib-tb`) |
| 2 | Secure Enclave (interface 7, classe `ff/f9/11`), rede NCM privada com o T1, display da Touch Bar (o host desenha), câmera | macOS e T1Bridge |
| 3 | variante sem o Secure Enclave | — |

O Touch ID **exige** a configuração 2. Nela, o T1 deixa de desenhar a Touch
Bar, então o T1Bridge assume essa tarefa (`appletbdrm` + `t1-touchbar`).
Por isso o driver antigo da Touch Bar não convive com o Touch ID. Isso é uma
limitação do hardware, não uma escolha de empacotamento.

## 2. usbmuxd força o iBridge de volta para o modo 1 (Fedora, Debian, Ubuntu)

Sintoma: Touch Bar apagada. No kernel log, as interfaces aparecem como
`1-3:2.x` e, segundos depois, como `1-3:1.x`.

Causa: a regra `/usr/lib/udev/rules.d/39-usbmuxd.rules` do usbmuxd (o
serviço de iPhone) tem:

```
ENV{PRODUCT}=="5ac/8600/*", ACTION=="add", ..., ATTR{bConfigurationValue}="1", ...
```

Ela desfaz a escolha do `t1_cfgsel`. No Arch, essa regra não está presente.

Correção: o pacote `t1bridge` grava em `/etc/udev/rules.d/39-usbmuxd.rules`,
que tem prioridade sobre o mesmo nome em `/usr/lib`, uma cópia da regra
original **sem** as menções a `5ac/8600`. iPhones continuam funcionando. A
cópia é regenerada a cada atualização do usbmuxd, por `%triggerin` no RPM e
por trigger `interest-noawait` no dpkg.

## 3. SELinux: serviços rodando como `init_t` (só Fedora)

Sintoma: `t1-touchbar-hw: Touch Bar input failed` em loop e centenas de AVCs
`init_t → usb_device_t:chr_file`.

Causa: os executáveis ficam em `/usr/lib/t1bridge/`, que a política base
rotula como `lib_t`. O systemd não faz transição de domínio para `lib_t`,
então os serviços continuam como `init_t`, que não pode abrir `hidraw` nem
`usbfs`. Além disso, o `fprintd` confinado (`fprintd_t`) não pode conectar ao
socket do broker.

Correção: módulo `t1bridge` (pacote `t1bridge-selinux`):

- `t1bridge.fc`: `/usr/lib/t1bridge(/.*)?` recebe o rótulo `bin_t`, e os
  serviços passam a rodar como `unconfined_service_t`, igual a qualquer
  serviço de terceiros;
- `t1bridge.te`: `fprintd_t` ganha `connectto` em `init_t` e
  `unconfined_service_t`, `write` no `sock_file` e `search` no diretório
  `var_run_t`.

## 4. initramfs gerado com o driver antigo (Fedora)

O `%post` do `t1bridge-dkms` regenerava o initramfs **antes** de o dnf
remover o `mbp-t1-touchbar-dkms`, e o arquivo `modules-load.d` do driver
antigo ia parar dentro do initramfs. A geração passou para o `%posttrans`,
que roda depois da transação inteira.

## 5. `--allowerasing` removeria o `fprintd-pam` (Fedora)

O `fprintd-pam` e o `libfprint-devel` do Fedora exigem a versão exata do
par. Um `dnf install --allowerasing` só com `libfprint` e `fprintd` novos os
**removeria**, e a digital deixaria de funcionar no login. O instalador
agora inclui todos os subpacotes já instalados e aplica `dnf versionlock`.
No Debian e no Ubuntu, o `install.sh` faz o mesmo com `apt-mark hold`.

## 6. libfprint diferente em cada distro

| Distro | libfprint | Patch do driver |
| --- | --- | --- |
| Arch (upstream) | 1.94.100 (commit fixo) | original |
| Fedora 45 | 1.94.100 | original, aplicado sem mudanças |
| Debian 13 | 1.94.9 | **portado**: listas `default_drivers` e `endian_independent_drivers` em vez de dicionários; função auxiliar movida |
| Ubuntu 26.04 | 1.95.1+tod1 | **portado**: o enum `FpDeviceType` tem outra ordem (ABI do TOD), então `FP_DEVICE_TYPE_USB_PRESENCE` vai **no fim**; a função auxiliar é `G_GNUC_INTERNAL` para não virar símbolo exportado do `libfprint-2-tod1` (o `dpkg-gensymbols` rejeita símbolos novos) |

Em todos os casos, o pacote **da própria distro** é recompilado com o patch,
mantendo os nomes dos pacotes (`libfprint`, `libfprint-2-2`, `fprintd`,
`libpam-fprintd`...). Assim GNOME, `authselect` e `pam-auth-update` continuam
funcionando. O sufixo `.t1bridge` ou `+t1bridge1` torna a versão maior que a
da distro.

O patch do `fprintd` (iniciar o cadastro direto quando o driver faz a
detecção de duplicatas) aplicou sem mudanças nas três distros.

## 7. Detalhes menores

- **Primeiro cadastro:** a primeira tentativa pode falhar com
  `enroll-unknown-error` (`prepare device keybag failed`), principalmente
  logo depois de o `t1-xart-storage` reiniciar. Na segunda tentativa, o
  Secure Enclave já tem o keybag e o cadastro conclui. O upstream documenta
  o mesmo padrão.
- **Firewall:** o xART precisa de TCP 61500 via IPv6 na interface NCM do
  T1. No Fedora Workstation, a zona padrão já libera as portas 1025–65535. No
  Debian e no Ubuntu, só é preciso agir se o `ufw` estiver ativo (veja
  `debian.md`).
- **Rust:** o T1Bridge exige rustc 1.88 ou mais (edition 2024). O Debian 13
  tem 1.85, então o build Debian usa `rustup`.
- **Binários por distro:** cada `.deb` é compilado num container da própria
  distro (`podman`), contra a glibc e as bibliotecas dela.

## O que foi testado

| | Fedora 45 (hardware real, `MacBookPro14,2`) | Debian 13 / Ubuntu 26.04 |
| --- | --- | --- |
| Compilação | sim | sim (containers) |
| Instalação dos pacotes e scripts | sim | sim (containers limpos) |
| Máscara do usbmuxd | sim | sim (containers) |
| Touch Bar acesa | sim | **não testado** |
| Cadastro e `verify-match` | sim | **não testado** |
| `sudo` com digital e com senha | sim | **não testado** |
