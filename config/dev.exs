import Config

config :xtlsmlpp,
  TcpClient: [
    {{"127.0.0.1", 9999}, []}
  ],
  TcpServer: [
    {{"127.0.0.1", 9999}, []}
  ]
