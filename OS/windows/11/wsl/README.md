## linuxbrew

```zsh
sudo apt install -y build-essential procps curl file
/bin/bash -c "$(curl --no-keepalive -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.zshrc
echo "export HOMEBREW_CURLRC=1" >> ~/.zshrc
echo "cacert /etc/ssl/certs/ca-certificates.crt" >> ~/.curlrc
```
