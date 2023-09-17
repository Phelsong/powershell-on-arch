# This is for installing pwsh-preview only. There is a AUR package for stable powershell

curl -L -o /tmp/powershell.tar.gz https://github.com/PowerShell/PowerShell/releases/download/v7.4.0-preview.5/powershell-7.4.0-preview.5-linux-x64.tar.gz
sudo mkdir -p /opt/microsoft/powershell/7
sudo tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7
sudo chmod +x /opt/microsoft/powershell/7/pwsh
sudo ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh

echo /bin/pwsh >> /etc/shells
# chsh $user
# /bin/pwsh
