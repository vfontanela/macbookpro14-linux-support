# Touch ID no Debian 13 e Ubuntu 26.04 (MacBook Pro T1)

Pacotes `.deb` não oficiais do T1Bridge para **Debian 13 (trixie)** e
**Ubuntu 26.04 LTS**, nos MacBook Pro 2016/2017 com Touch Bar e chip **T1**
(`MacBookPro13,2`, `13,3`, `14,2`, `14,3`).

> **Estado:** os `.deb` são gerados pelo mesmo procedimento do port para
> Fedora, que foi testado de ponta a ponta em um `MacBookPro14,2` (Touch Bar,
> cadastro, verificação e `sudo` com digital). Os `.deb` em si **ainda não
> foram testados em hardware**. Se testar, relate o resultado.

O funcionamento interno é o mesmo descrito em [touch-id.md](https://github.com/standardagents/t1bridge/blob/81cbdf81026a16e02f0bea74735c6b029a8ffae2/docs/touch-id.md). As
diferenças de distribuição estão em [fedora.md](fedora.md), na seção
"Diferenças em relação ao empacotamento Arch".

## O que é instalado

| Pacote | Conteúdo |
| --- | --- |
| `t1bridge` | Serviços, importador, broker do Touch ID e renderizador da Touch Bar |
| `t1bridge-dkms` | Módulos `t1_cfgsel`, `apple_t1_ncm`, `appletbdrm` (T1) e `uvcvideo` com patch, recompilados pelo DKMS a cada kernel; integração com initramfs-tools **e** dracut |
| `libfprint-2-2` (`…+t1bridge1`) | A libfprint **da própria distro**, recompilada com o driver `t1bridge` |
| `fprintd`, `libpam-fprintd` (`…+t1bridge1`) | O fprintd da distro, com o patch de detecção nativa de duplicatas |

O patch do driver foi portado para a libfprint de cada distro: 1.94.9 no
Debian e 1.95.1+tod1 no Ubuntu. No Ubuntu, o tipo novo de dispositivo foi
acrescentado **no fim** do enum, para preservar a ABI do `libfprint-2-tod1`.
O instalador aplica `apt-mark hold` nesses pacotes para que uma atualização
da distro não remova o driver.

Pontos específicos de Debian e Ubuntu:

- **usbmuxd:** a regra udev dele força o iBridge para a configuração USB 1,
  que não tem Secure Enclave. O pacote `t1bridge` grava uma cópia sem o
  iBridge em `/etc/udev/rules.d/39-usbmuxd.rules` e a regenera, por trigger
  do dpkg, a cada atualização do usbmuxd. A primeira linha
  (`# t1bridge: generated ...`) marca a cópia como do pacote; um arquivo
  **seu** com esse nome nunca é sobrescrito nem apagado (o pacote avisa, e você
  remove dele as entradas `5ac/8600`).
- **initramfs:** `t1_cfgsel` precisa estar no initramfs. O pacote instala
  `/usr/share/initramfs-tools/modules.d/t1bridge` (Debian) e
  `/usr/lib/dracut/dracut.conf.d/90-t1bridge.conf` (Ubuntu 26.04 usa dracut),
  e regenera o que estiver em uso.
- **Drivers antigos da Touch Bar** (`apple_ibridge`, `apple_ib_tb`,
  `apple_ib_als`, por exemplo do `macbook12-spi-driver-dkms`) são desativados
  por `/usr/lib/modprobe.d/t1bridge.conf`. Eles mantêm o T1 num modo sem
  Touch ID.
- **Sem SELinux:** os problemas de SELinux do Fedora não se aplicam.
- **Firewall:** o xART precisa receber TCP 61500 via IPv6 **só** na interface
  NCM do T1. Sem firewall ativo (padrão do Debian e do Ubuntu desktop), nada
  a fazer. Com `ufw` ativo:

  ```sh
  ifc=$(ls /sys/bus/usb/drivers/apple_t1_ncm/*/net)
  sudo ufw allow in on "$ifc" to any port 61500 proto tcp
  ```

## Antes de tudo: o `FDRData` da Apple

O Touch ID precisa da calibração de fábrica **desta** máquina:
`EFI/APPLE/EMBEDDEDOS/FDRData`, na partição EFI original. Confira e faça
backup antes de instalar ou formatar qualquer coisa:

```sh
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,MOUNTPOINTS   # a ESP é a "EFI System"
sudo ls -l /boot/efi/EFI/APPLE/EMBEDDEDOS/            # ajuste se a ESP estiver montada em outro lugar
sudo tar -C /boot/efi -czf ~/apple-efi-backup.tar.gz EFI/APPLE
```

Sem esse arquivo, ou com o de outro Mac, o Touch ID não funciona. Guarde o
backup fora da máquina e não o publique.

## Instalar

Na pasta com os `.deb` da sua distro (`deb/debian-13/` ou
`deb/ubuntu-26.04/`):

```sh
sudo apt install dkms linux-headers-$(uname -r)
sudo ./install.sh
sudo reboot
```

O instalador confere modelo, distro, arquitetura e `SHA256SUMS`, e o **apt
mostra a transação e pergunta antes de aplicar**. Ele aplica `apt-mark hold`
nos pacotes recompilados e registra em `/var/lib/t1bridge-port/held` quais
travas criou. O PAM **não** é alterado.

Se o DKMS ou o initramfs falharem, o `t1bridge-dkms` fica como "não
configurado" e mostra `t1bridge-dkms: ERROR: ...`. **Não reinicie** antes de
resolver (normalmente falta `linux-headers-$(uname -r)`); depois rode
`sudo dpkg --configure -a`.

Depois do reboot, a Touch Bar deve acender. Para conferir:

```sh
sudo t1bridge status          # "keybag: not-enrolled" é esperado antes do cadastro
```

## Importar a calibração e cadastrar a digital

```sh
sudo systemctl start t1bridge-import.service
systemctl status t1bridge-import.service

# no terminal da sessão gráfica (o polkit pede a senha):
fprintd-enroll -f right-index-finger
fprintd-verify -f right-index-finger
```

O resultado esperado é `enroll-completed` e depois `verify-match`. No
primeiro cadastro, uma tentativa pode falhar com `enroll-unknown-error`
enquanto o Secure Enclave cria o keybag. Repita o comando e **não** apague
`/var/lib/t1bridge`.

## Login, sudo e polkit

Com um shell root aberto à parte:

```sh
sudo pam-auth-update --enable fprintd
```

Teste cada consumidor (`sudo`, polkit, tela de bloqueio, login)
separadamente: com a digital; com a senha sem tocar o sensor; com a senha e o
serviço parado
(`sudo systemctl stop t1-touchid-auth.service t1bridge-fingerprint.socket t1-touchid-auth.socket`);
e cancelando o pedido de digital. Nada disso foi testado em hardware com os
`.deb` ainda. Para desfazer: `sudo pam-auth-update --disable fprintd`.

## Diagnóstico

```sh
sudo t1bridge status
journalctl -b -u t1-touchbar-hw -u t1-touchid-auth -u 't1-xart-storage@*' -u fprintd
dkms status t1bridge-dkms
cat /sys/bus/usb/devices/*/bConfigurationValue   # o iBridge (05ac:8600) precisa estar em 2
```

Modo detalhado: veja [diagnostics.md](https://github.com/standardagents/t1bridge/blob/81cbdf81026a16e02f0bea74735c6b029a8ffae2/docs/diagnostics.md) (`/etc/t1bridge/diagnostics.conf`).

## Remover

Com um shell root aberto à parte:

```sh
sudo pam-auth-update --disable fprintd            # e teste o login por senha
sudo apt-mark unhold $(cat /var/lib/t1bridge-port/held) && sudo rm /var/lib/t1bridge-port/held
sudo apt remove t1bridge t1bridge-dkms
# volta TODOS os pacotes recompilados (+t1bridge1) às versões da distro:
codename=$(. /etc/os-release; echo "$VERSION_CODENAME")
pkgs=$(dpkg-query -W -f='${Package} ${Version}\n' | awk '/\+t1bridge/ {print $1"/"c}' c="$codename")
sudo apt install --allow-downgrades $pkgs
dpkg-query -W -f='${Package} ${Version}\n' | grep t1bridge   # não deve listar nada
```

Confira que o `t1_cfgsel` saiu do initramfs do kernel em uso
(`lsinitramfs /boot/initrd.img-$(uname -r) | grep -c t1_cfgsel` deve dar 0).
A máscara do usbmuxd é removida junto com o pacote, só se for a gerada por ele.
O estado em `/var/lib/t1bridge` e a partição EFI da Apple não são apagados.
