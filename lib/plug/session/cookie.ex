defmodule Plug.Session.COOKIE do
  @moduledoc """
  Stores the session in a cookie.

  This cookie store is based on `Plug.Crypto.MessageVerifier`
  and `Plug.Crypto.Message.Encryptor` which encrypts and signs
  each cookie to ensure they can't be read nor tampered with.

  Since this store uses crypto features, it requires you to
  set the `:secret_key_base` field in your connection. This
  can be easily achieved with a plug:

      plug :put_secret_key_base

      def put_secret_key_base(conn, _) do
        put_in conn.secret_key_base, "-- LONG STRING WITH AT LEAST 64 BYTES --"
      end

  ## Cookie serializers

  See `Plug.Session.COOKIE.Serializer` for the specification cookie serializers are required to
  implement.

  Plug ships with the following cookie serializers:

  * `Plug.Session.COOKIE.ETF`
  * `Plug.Session.COOKIE.JSON`

  ## Options

  * `:encrypt` - specify whether to encrypt cookies, defaults to true.
    When this option is false, the cookie is still signed, meaning it
    can't be tempered with but its contents can be read

  * `:encryption_salt` - a salt used with `conn.secret_key_base` to generate
    a key for encrypting/decrypting a cookie

  * `:signing_salt` - a salt used with `conn.secret_key_base` to generate a
    key for signing/verifying a cookie.

  * `:serializer` - cookie serializer module (defaults to `:etf`).

  ## Examples

      # Use the session plug with the table name
      plug Plug.Session, store: :cookie,
                         key: "_my_app_session",
                         encryption_salt: "cookie store encryption salt",
                         signing_salt: "cookie store signing salt",
                         serializer: :json,
                         json_encoder: Poison
  """

  @behaviour Plug.Session.Store

  alias Plug.Crypto.KeyGenerator
  alias Plug.Crypto.MessageVerifier
  alias Plug.Crypto.MessageEncryptor

  def init(opts) do
    encryption_salt = check_encryption_salt(opts)
    signing_salt = check_signing_salt(opts)
    serializer = convert_serializer(opts[:serializer] || :etf)
    serializer_opts = Keyword.drop(opts, [:signing_salt, :encrypt, :encrypt_salt, :serializer])
    serialzer_config = serializer.init(serializer_opts)

    %{encryption_salt: encryption_salt,
      signing_salt: signing_salt,
      serializer: serializer,
      serializer_config: serialzer_config}
  end

  def get(conn, cookie, opts) do
    if key = opts.encryption_salt do
      MessageEncryptor.verify_and_decrypt(cookie, derive(conn, key), derive(conn, opts.signing_salt))
    else
      MessageVerifier.verify(cookie, derive(conn, opts.signing_salt))
    end |> decode(opts.serializer, opts.serializer_config)
  end

  def put(conn, _sid, term, opts) do
    binary = encode(term, opts.serializer, opts.serializer_config)
    if key = opts.encryption_salt do
      MessageEncryptor.encrypt_and_sign(binary, derive(conn, key), derive(conn, opts.signing_salt))
    else
      MessageVerifier.sign(binary, derive(conn, opts.signing_salt))
    end
  end

  def delete(_conn, _sid, _opts) do
    :ok
  end

  defp encode(term, serializer, serializer_config) do
    case serializer.encode(term, serializer_config) do
      {:ok, binary} -> binary
      :error -> nil
    end
  end

  defp decode({:ok, binary}, serializer, serializer_config) do
    case serializer.decode(binary, serializer_config) do
      {:ok, term} -> {nil, term}
      :error -> {nil, %{}}
    end
  end
  defp decode(:error, _serializer, _serializer_config), do:
    {nil, %{}}

  defp derive(conn, key) do
    conn.secret_key_base
    |> validate_secret_key_base()
    |> KeyGenerator.generate(key, cache: Plug.Keys)
  end

  defp validate_secret_key_base(nil), do:
    raise(ArgumentError, "cookie store expects conn.secret_key_base to be set")
  defp validate_secret_key_base(secret_key_base) when byte_size(secret_key_base) < 64, do:
    raise(ArgumentError, "cookie store expects conn.secret_key_base to be at least 64 bytes")
  defp validate_secret_key_base(secret_key_base), do:
    secret_key_base

  defp check_signing_salt(opts) do
    case opts[:signing_salt] do
      nil  -> raise ArgumentError, "cookie store expects :signing_salt as option"
      salt -> salt
    end
  end

  defp check_encryption_salt(opts) do
    if Keyword.get(opts, :encrypt, true) do
      case opts[:encryption_salt] do
        nil  -> raise ArgumentError, "encrypted cookie store expects :encryption_salt as option"
        salt -> salt
      end
    end
  end

  defp convert_serializer(serializer) do
    case Atom.to_string(serializer) do
      "Elixir." <> _ -> serializer
      reference      -> Module.concat(Plug.Session.COOKIE, String.upcase(reference))
    end
  end
end
