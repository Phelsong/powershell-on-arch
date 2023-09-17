gc /var/log/Xorg.0.log | Select-String amdgpu | Format-Table
sudo dmesg | Select-String amdgpu | Format-Table
sudo lsmod | Select-String amd | Format-Table
