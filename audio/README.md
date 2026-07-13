# CS8409 Audio Fix — MacBookPro14,2

The internal speakers of the MacBookPro14,2 use a Cirrus Logic CS8409 codec that is detected by Linux, but the internal speaker amplifiers are not initialized correctly by the generic driver.

This fix uses the community driver:

https://github.com/davidjo/snd_hda_macbookpro

## Installation

```bash
sudo apt update
sudo apt install -y git dkms build-essential linux-headers-$(uname -r) linux-source

git clone https://github.com/davidjo/snd_hda_macbookpro.git
cd snd_hda_macbookpro

sudo bash install.cirrus.driver.sh
sudo bash dkms.sh

sudo reboot



Tested on
MacBookPro14,2
Kubuntu 26.04
Linux 7.0.0-27-generic
Cirrus Logic CS8409
Credits

Audio driver by davidjo and contributors.
