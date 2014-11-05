defmodule Plug.Crypto.MessageEncryptor do
  @moduledoc ~S"""
  `MessageEncryptor` is a simple way to encrypt values which get stored
  somewhere you don't trust.

  The cipher text and initialization vector are base64 encoded and
  returned to you.

  This can be used in situations similar to the `MessageVerifier`, but where
  you don't want users to be able to determine the value of the payload.

  ## Example

      secret_key_base = "072d1e0157c008193fe48a670cce031faa4e..."
      encrypted_cookie_salt = "encrypted cookie"
      encrypted_signed_cookie_salt = "signed encrypted cookie"

      secret = KeyGenerator.generate(secret_key_base, encrypted_cookie_salt)
      sign_secret = KeyGenerator.generate(secret_key_base, encrypted_signed_cookie_salt)
      encryptor = MessageEncryptor.new(secret, sign_secret)

      data = %{current_user: %{name: "José"}}
      encrypted = MessageEncryptor.encrypt_and_sign(encryptor, data)
      decrypted = MessageEncryptor.verify_and_decrypt(encryptor, encrypted)
      decrypted.current_user.name # => "José"
  """

  alias Plug.Crypto.MessageVerifier

  @doc """
  Encrypts and signs a message.
  """
  def encrypt_and_sign(message, secret, sign_secret, cipher \\ :aes_cbc256)
      when is_binary(message) and is_binary(secret) and is_binary(sign_secret) do
    iv = :crypto.strong_rand_bytes(16)

    message
    |> pad_message
    |> encrypt(cipher, secret, iv)
    |> Base.encode64()
    |> Kernel.<>("--#{Base.encode64(iv)}")
    |> MessageVerifier.sign(sign_secret)
  end

  @doc """
  Decrypts and verifies a message.

  We need to verify the message in order to avoid padding attacks.
  Reference: http://www.limited-entropy.com/padding-oracle-attacks
  """
  def verify_and_decrypt(encrypted, secret, sign_secret, cipher \\ :aes_cbc256)
      when is_binary(encrypted) and is_binary(secret) and is_binary(sign_secret) do
    case MessageVerifier.verify(encrypted, sign_secret) do
      {:ok, verified} ->
        [encrypted, iv] = String.split(verified, "--") |> Enum.map(&Base.decode64!/1)
        encrypted |> decrypt(cipher, secret, iv) |> unpad_message
      :error ->
        :error
    end
  end

  defp encrypt(message, cipher, secret, iv) do
    :crypto.block_encrypt(cipher, trim_secret(secret), iv, message)
  end

  defp decrypt(encrypted, cipher, secret, iv) do
    :crypto.block_decrypt(cipher, trim_secret(secret), iv, encrypted)
  end

  defp pad_message(msg) do
    bytes_remaining = rem(byte_size(msg) + 1, 16)
    padding_size = if bytes_remaining == 0, do: 0, else: 16 - bytes_remaining
    <<padding_size>> <> msg <> :crypto.strong_rand_bytes(padding_size)
  end

  defp unpad_message(msg) do
    <<padding_size, rest::binary>> = msg
    msg_size = byte_size(rest) - padding_size
    case rest do
      <<msg::binary-size(msg_size), _::binary>> -> {:ok, msg}
      _ -> :error
    end
  end

  defp trim_secret(secret) do
    case byte_size(secret) do
      large when large > 32 -> :binary.part(secret, 0, 32)
      _ -> secret
    end
  end
end
