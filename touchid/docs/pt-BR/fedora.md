# Touch ID no Fedora (MacBook Pro T1)

Este guia é o port para Fedora do T1Bridge, que hoje só tem pacotes oficiais
para Arch. Ele vale para os MacBook Pro 2016/2017 com Touch Bar e chip **T1**
(`MacBookPro13,2`, `13,3`, `14,2`, `14,3`) e foi escrito e testado em um
`MacBookPro14,2` com Fedora 45 (kernel 7.2.11, SELinux em modo enforcing).
Nesse teste funcionaram a Touch Bar, o cadastro, `fprintd-verify`
(`verify-match`), `sudo` com a digital e `sudo` com a senha como alternativa.
Macs com T2, Apple Silicon e modelos sem Touch Bar não são suportados.

Leia também [setup.md](https://github.com/standardagents/t1bridge/blob/81cbdf81026a16e02f0bea74735c6b029a8ffae2/docs/setup.md) (procedimento geral) e
[touch-id.md](https://github.com/standardagents/t1bridge/blob/81cbdf81026a16e02f0bea74735c6b029a8ffae2/docs/touch-id.md) (como funciona).

## Como funciona, em resumo

O sensor do Touch ID não é um leitor USB comum: a captura e a comparação da
digital acontecem dentro do Secure Enclave (SEP) do chip T1. O Linux nunca vê
a imagem da digital, só recebe o resultado "confere" ou "não confere".

```
fprintd ──► libfprint (driver "t1bridge") ──► /run/t1bridge/fingerprint.sock
                                                   │
                                     t1-touchid-auth (broker, root)
                                                   │  usbfs + link NCM privado (IPv6)
                                             T1 / Secure Enclave
```

| Componente | Pacote Fedora | Função |
| --- | --- | --- |
| `t1_cfgsel`, `apple_t1_ncm`, `appletbdrm`, `uvcvideo` | `t1bridge-dkms` | Coloca o T1 na configuração USB 2, que expõe a interface do SEP, a rede NCM privada e o display da Touch Bar |
| Serviços (`t1-xart-storage`, `t1-keybag-relay`, `t1-touchid-auth`, `t1-touchbar*`) | `t1bridge` | Armazenamento anti-replay (xART), keybag do SEP, broker de autenticação e Touch Bar |
| Política `t1bridge_fprintd` | `t1bridge-selinux` | Permite que o `fprintd` confinado conecte ao socket do broker |
| `libfprint` + driver `t1bridge` | `libfprint-…t1bridge` | Fedora's libfprint recompilada com o patch do driver |
| `fprintd` + detecção nativa de duplicatas | `fprintd-…t1bridge` | Fedora's fprintd recompilado com o patch de compatibilidade |

### Diferenças em relação ao empacotamento Arch

- `mkinitcpio` → **dracut**: `/usr/lib/dracut/dracut.conf.d/90-t1bridge.conf`
  inclui `t1_cfgsel` no initramfs. O `%posttrans` do `t1bridge-dkms` compila
  os módulos para todos os kernels instalados e regenera o initramfs. Isso
  acontece no fim da transação, depois que o driver antigo já foi removido.
  Nos próximos kernels, o DKMS do Fedora recompila automaticamente.
- **usbmuxd** (Fedora, Debian e Ubuntu; o Arch não tem): a regra `/usr/lib/udev/rules.d/39-usbmuxd.rules`
  força `bConfigurationValue=1` em todo `05ac:8600`, ou seja, no iBridge, e
  desfaz a escolha do `t1_cfgsel` segundos depois do boot. O sintoma é a Touch
  Bar apagada e o iBridge na configuração 1. Um trigger do pacote `t1bridge`
  grava em `/etc/udev/rules.d/39-usbmuxd.rules` uma cópia da regra sem o
  iBridge, que tem prioridade sobre a original. iPhones continuam funcionando,
  e a cópia é regenerada a cada atualização do usbmuxd. A primeira linha da
  cópia (`# t1bridge: generated ...`) marca o arquivo como do pacote. Se já
  existir um `/etc/udev/rules.d/39-usbmuxd.rules` **seu**, sem essa linha, ele
  nunca é sobrescrito nem apagado; o pacote só avisa, e você precisa remover
  dele as entradas `5ac/8600`.
- `libfprint`/`fprintd` **não** são trocados por pacotes com outro nome. Os
  SRPMs do próprio Fedora são recompilados com os patches e o sufixo
  `.t1bridge` no release (ex.: `libfprint-1.94.100-1.t1bridge.fc45`). Assim
  GNOME, `fprintd-pam` etc. continuam satisfeitos. O instalador aplica
  `dnf versionlock` para que uma atualização do Fedora não reverta para a
  versão sem o driver e quebre o Touch ID silenciosamente.
- **SELinux** (módulo `t1bridge`, pacote `t1bridge-selinux`):
  - os executáveis ficam em `/usr/lib/t1bridge`, que a política base rotula
    como `lib_t`. Com esse rótulo, o systemd não faz transição de domínio, e
    os serviços rodam como `init_t`, que é proibido de abrir o `hidraw` e o
    `usbfs` do T1 (`usb_device_t`). O sintoma é `t1-touchbar-hw: Touch Bar
    input failed` em loop e a Touch Bar apagada. O módulo rotula essa pasta
    como `bin_t`, então os serviços rodam como `unconfined_service_t`, igual a
    outros serviços de terceiros;
  - o `fprintd` roda confinado (`fprintd_t`), e o módulo permite que ele
    conecte ao socket `SOCK_SEQPACKET` do broker.

  **Limite atual:** isso não é confinamento. Os serviços do T1Bridge rodam
  como `unconfined_service_t` (o padrão do Fedora para serviços de terceiros)
  e o socket usa o tipo genérico `var_run_t`. A proteção vem do próprio
  T1Bridge (sandbox do systemd, sockets root-only, verificação do peer), não do
  SELinux. Uma política com domínio e tipo de socket próprios ainda não existe.
- `t1bridge-dkms` declara `Conflicts: mbp-t1-touchbar-dkms`. O driver
  antigo da Touch Bar (`apple_ibridge`, `apple_ib_tb`, `apple_ib_als`) mantém o
  T1 na configuração USB 1, que não tem a interface do Secure Enclave. Ele é
  removido, e a Touch Bar passa a ser desenhada pelo `t1-touchbar` do T1Bridge.
- **Firewall**: o xART precisa receber TCP 61500 via IPv6 **apenas** na
  interface NCM privada do T1. A interface não é gerenciada pelo
  NetworkManager (`NM_UNMANAGED=1`), então cai na zona padrão do firewalld.
  No Fedora Workstation (zona `FedoraWorkstation`), as portas 1025–65535 já
  são permitidas. Se você usa outra zona padrão, veja
  [Firewall](#firewall).

## Pré-requisitos

1. **`FDRData` da Apple preservado.** O Touch ID precisa da calibração de
   fábrica desta máquina em `EFI/APPLE/EMBEDDEDOS/FDRData`, na partição EFI
   original da Apple. Sem esse arquivo, ou com o de outro Mac, não funciona.
   Confira e faça backup **antes** de qualquer coisa:

   ```sh
   sudo ls -l /boot/efi/EFI/APPLE/EMBEDDEDOS/
   sudo tar -C /boot/efi -czf ~/apple-efi-backup.tar.gz EFI/APPLE
   ```

   Guarde o backup fora deste disco. Nunca o publique, porque ele é específico
   da máquina.
2. Uma senha funcionando e, ao mexer em PAM, um shell root aberto à parte.

## Compilar

Dependências de build (uma vez):

```sh
cd ~/src/t1bridge
dnf download --source libfprint fprintd --destdir ~/rpmbuild/SRPMS
rpm -i ~/rpmbuild/SRPMS/{libfprint,fprintd}-*.src.rpm
sudo dnf -y builddep packaging/fedora/t1bridge.spec \
  ~/rpmbuild/SPECS/libfprint.spec ~/rpmbuild/SPECS/fprintd.spec
```

Compilar os RPMs como usuário comum:

```sh
packaging/fedora/build.sh
```

Os RPMs ficam em `~/rpmbuild/RPMS/{x86_64,noarch}/`.

Alternativa isolada, sem instalar dependências no sistema (precisa de
`podman` ou `docker`); é assim que os RPMs publicados são gerados:

```sh
packaging/fedora/build-container.sh ./dist/rpm/fedora-45
SKIP_FPRINT=1 packaging/fedora/build-container.sh ./out   # só os pacotes t1bridge
```

## Instalar

```sh
sudo packaging/fedora/install.sh
sudo reboot
```

O instalador verifica o modelo, a versão do Fedora, a arquitetura e o
`SHA256SUMS`. Depois o **dnf mostra a transação e pergunta antes de aplicar**.
Leia a seção de remoções: o esperado é só o `mbp-t1-touchbar-dkms` (driver
antigo da Touch Bar). Se aparecer outra coisa, responda "N".

Em seguida ele aplica o versionlock (registrando em
`/var/lib/t1bridge-port/versionlocked` quais travas ele criou), cria o grupo
`t1bridge`, adiciona seu usuário a ele, habilita os serviços e informa se o
login por digital está ativo no `authselect`.

Se a compilação do módulo pelo DKMS ou o initramfs falharem, a instalação
mostra `t1bridge-dkms: ERROR: ...` e `warning: %posttrans(...) scriptlet
failed`. **Não reinicie** antes de resolver: sem o módulo, a Touch Bar fica
apagada e o Touch ID indisponível. A causa mais comum é faltar o
`kernel-devel` do kernel em uso (`sudo dnf install kernel-devel-$(uname -r)`,
depois `sudo dnf reinstall t1bridge-dkms`).

Depois do reboot:

```sh
sudo t1bridge status        # "keybag: not-enrolled" é esperado antes do 1º cadastro
lsusb -v -d 05ac:8600 2>/dev/null | grep bConfigurationValue   # deve existir a config 2
cat /sys/bus/usb/devices/*/bConfigurationValue 2>/dev/null     # o iBridge deve estar em 2
```

## Importar a calibração da Apple

Com o leitor ocioso:

```sh
sudo systemctl start t1bridge-import.service
systemctl status t1bridge-import.service
```

Ou, a partir do backup extraído em um diretório:

```sh
sudo t1bridge machine-data import --from /caminho/para/backup   # contém EFI/APPLE/EMBEDDEDOS/FDRData
```

Os códigos de saída do importador estão em [setup.md](https://github.com/standardagents/t1bridge/blob/81cbdf81026a16e02f0bea74735c6b029a8ffae2/docs/setup.md).

## Cadastrar a digital

Faça isso **no terminal da sessão gráfica**, porque o polkit precisa mostrar
o pedido de senha. Não use `sudo fprintd-enroll`.

```sh
fprintd-list "$(id -un)"
fprintd-enroll -f right-index-finger
fprintd-verify -f right-index-finger
```

O resultado esperado é `enroll-completed` e depois `verify-match`. No primeiro
cadastro, o Secure Enclave ainda precisa criar o keybag, e uma primeira
tentativa pode falhar com `enroll-unknown-error` (no journal do
`t1-touchid-auth`: `prepare device keybag failed`), principalmente logo depois
de reiniciar o `t1-xart-storage`. Espere alguns segundos e repita o comando.
Não apague nada em `/var/lib/t1bridge`. Se falhar de novo, ligue o
[diagnóstico](https://github.com/standardagents/t1bridge/blob/81cbdf81026a16e02f0bea74735c6b029a8ffae2/docs/diagnostics.md). É possível
cadastrar até três dedos. Também dá para usar *Configurações → Usuários →
Login por impressão digital* do GNOME.

## Usar no login, sudo e polkit

No Fedora, o PAM é controlado pelo `authselect`. Na instalação padrão do
Fedora Workstation, o perfil costuma ter o recurso `with-fingerprint`: o
`system-auth` usa `pam_fprintd` como `sufficient`, com a senha logo em seguida
como alternativa. **O instalador não ativa isso**; ele só informa o estado.
Confira e, se faltar, ative:

```sh
authselect current
sudo authselect enable-feature with-fingerprint
sudo authselect apply-changes
```

Isso vale para GDM, tela de bloqueio, `sudo` e polkit. Antes de fechar o
shell root de recuperação, teste **cada um separadamente**:

1. com a digital;
2. com a senha, sem tocar o sensor (esperar o tempo limite);
3. com a senha e o serviço parado, simulando o leitor indisponível:
   `sudo systemctl stop t1-touchid-auth.service t1bridge-fingerprint.socket t1-touchid-auth.socket`
   (depois `sudo systemctl start t1bridge-fingerprint.socket t1-touchid-auth.socket`);
4. cancelando o pedido de digital (Ctrl+C no `sudo`, "Cancelar" no polkit).

No `MacBookPro14,2` de referência foram testados só `sudo` com digital e
`sudo` com senha sem tocar o sensor. Os demais casos ainda precisam ser
verificados por quem instalar. Para desativar:
`sudo authselect disable-feature with-fingerprint && sudo authselect apply-changes`.

## Firewall

Para confirmar que a porta do xART está liberada na interface do T1:

```sh
ifc=$(ls /sys/bus/usb/drivers/apple_t1_ncm/*/net)   # interface NCM do T1
ip -br addr show dev "$ifc"                          # deve ter um endereço fe80::
firewall-cmd --get-zone-of-interface="$ifc" || firewall-cmd --get-default-zone
firewall-cmd --zone="$(firewall-cmd --get-default-zone)" --list-ports
```

Se a zona padrão não permite 61500/tcp, coloque **somente** a interface do T1
em uma zona própria. O nome da interface é dinâmico, então refaça isso se
o nome mudar:

```sh
ifc=$(ls /sys/bus/usb/drivers/apple_t1_ncm/*/net)
sudo firewall-cmd --permanent --new-zone=t1bridge
sudo firewall-cmd --permanent --zone=t1bridge --add-port=61500/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --zone=t1bridge --change-interface="$ifc"
```

Nunca abra essa porta no Wi-Fi ou na Ethernet.

## Diagnóstico

```sh
sudo t1bridge status
journalctl -b -u t1-touchid-auth -u 't1-xart-storage@*' -u t1bridge-keybag -u fprintd --no-pager
sudo ausearch -m avc -ts boot | grep -E 'fprintd|t1'     # negações SELinux
dkms status t1bridge-dkms
lsinitrd | grep t1_cfgsel
```

Não apague `/var/lib/t1bridge` para "resetar": o estado do Secure Enclave e
o do disco precisam continuar pareados. Veja
[relay-recovery.md](https://github.com/standardagents/t1bridge/blob/81cbdf81026a16e02f0bea74735c6b029a8ffae2/docs/relay-recovery.md).

## Atualizações

- **Kernel:** o DKMS recompila os módulos e o dracut inclui o `t1_cfgsel`
  automaticamente.
- **libfprint/fprintd:** ficam travados por `dnf versionlock`. Quando o
  Fedora lançar uma versão nova, recompile (`packaging/fedora/build.sh` ou
  `build-container.sh`), libere as travas que o instalador criou
  (`sudo dnf versionlock delete $(cat /var/lib/t1bridge-port/versionlocked)`) e
  rode o `install.sh` de novo.
- **T1Bridge:** faça `git pull`, ajuste `Version:` em
  `packaging/fedora/t1bridge.spec` e recompile.

## Remover

Com um shell root aberto à parte:

1. `sudo authselect disable-feature with-fingerprint && sudo authselect apply-changes`,
   e teste o login por senha.
2. Libere só as travas criadas pelo instalador:
   `sudo dnf versionlock delete $(cat /var/lib/t1bridge-port/versionlocked) && sudo rm /var/lib/t1bridge-port/versionlocked`
3. `sudo dnf remove t1bridge t1bridge-dkms t1bridge-selinux`
4. Volte **todos** os subpacotes recompilados ao par do Fedora:
   `sudo dnf distro-sync $(rpm -qa --qf '%{NAME}\n' 'libfprint*' 'fprintd*')`
   e confira com `rpm -qa 'libfprint*' 'fprintd*'` que nenhum tem `t1bridge` no release.
5. Confira o initramfs do kernel em uso: `sudo lsinitrd | grep -c t1_cfgsel`
   deve dar 0 (se não, `sudo dracut -f`).
6. Opcional: reinstale `mbp-t1-touchbar-dkms` para a Touch Bar antiga.

A máscara do usbmuxd é removida junto com o pacote (só se for a gerada por
ele).

O estado em `/var/lib/t1bridge` e a partição EFI da Apple não são apagados.

## Limitações conhecidas (upstream)

- Suspensão: as funções do T1 podem não voltar depois de suspender. No
  `MacBookPro14,2` foi relatada tela preta da Touch Bar ao reabrir a tampa
  ([#14](https://github.com/standardagents/t1bridge/issues/14)).
- O autosuspend em runtime do T1 fica desativado.
- O `uvcvideo` do pacote substitui o módulo do kernel para **todas** as
  webcams USB. Ele é o upstream com dois patches pequenos.
