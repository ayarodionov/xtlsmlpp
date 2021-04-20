defmodule Util do
  @default_cert "cert.pem"
  @default_key "key.pem"
  @appl_name :tlsmlpp

  def default_credits(), do: default_credits(@default_cert, @default_key)

  def default_credits(cert, key) do
    priv_dir = priv_dir(@appl_name)
    [{:certfile, :filename.join(priv_dir, cert)}, {:keyfile, :filename.join(priv_dir, key)}]
  end

  def priv_dir(appl_name) do
    case :code.priv_dir(appl_name) do
      {:error, _} ->
        {:ok, pwd} = File.cwd()
        :filename.join(pwd, "priv")

      priv_dir ->
        priv_dir
    end
  end
end
