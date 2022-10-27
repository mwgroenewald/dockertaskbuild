FROM doringdraaiacr.azurecr.io/server2019core:latest

WORKDIR /azp

COPY start.ps1 .

CMD powershell .\start.ps1