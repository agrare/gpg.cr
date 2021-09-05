require "./lib_gpg"
require "./gpg/*"

class GPG
  @handle : LibGPG::Context

  if LibGPG.check_version("1.4.0").null?
    raise "GPGME version >= 1.4.0 is required"
  end

  def initialize
    gpg_error = LibGPG.new(out handle)
    Exception.raise_if_error(gpg_error)
    @handle = handle
  end

  def finalize
    LibGPG.release(@handle)
  end

  def list_keys(pattern = "", secret_only = false)
    gpg_error = LibGPG.op_keyslist_start(@handle, pattern, secret_only ? 1 : 0)
    Exception.raise_if_error(gpg_error)
    KeyIterator.new(@handle)
  end

  def encrypt(plain, *recipients, flags = LibGPG::EncryptFlags::None)
    plain_data = Data.new(plain).tap(&.rewind)
    cipher_data = Data.new

    recipients = Array.new(recipients.size + 1) do |i|
      recipients[i]?.try(&.to_unsafe) || Pointer(LibGPG::Key).null
    end

    gpg_error = LibGPG.op_encrypt(
      @handle, recipients, flags, plain_data, cipher_data
    )
    Exception.raise_if_error(gpg_error)
    cipher_data.tap(&.rewind).gets_to_end
  end

  def decrypt(cipher)
    plain_data = Data.new
    cipher_data = Data.new(cipher).tap(&.rewind)

    gpg_error = LibGPG.op_decrypt(@handle, cipher_data, plain_data)
    Exception.raise_if_error(gpg_error)
    plain_data.tap(&.rewind).gets_to_end
  end

  def sign(plain, mode = LibGPG::SigMode::Normal)
    plain_data = Data.new(plain).tap(&.rewind)
    sig_data = Data.new

    gpg_error = LibGPG.op_sign(@handle, plain_data, sig_data, mode)
    Exception.raise_if_error(gpg_error)
    sig_data.tap(&.rewind).gets_to_end
  end

  def detach_sign(plain)
    sign(plain, LibGPG::SigMode::Detach)
  end

  def signers
    Signers.new(@handle)
  end

  def pinentry_mode=(mode)
    gpg_error = LibGPG.set_pinentry_mode(@handle, mode)
    Exception.raise_if_error(gpg_error)
  end
end
