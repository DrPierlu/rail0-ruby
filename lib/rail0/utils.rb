# frozen_string_literal: true

require "digest"
require "securerandom"

module Rail0
  # Generates a checksummed RAIL0 payment ID (32 bytes, "0x"-prefixed hex).
  #
  # Layout:
  #   bytes  0.. 3  — last 4 bytes of SHA-256(payload)   ← checksum
  #   bytes  4..31  — 28 cryptographically-random bytes  ← payload
  #
  # The checksum lets Ponder (the on-chain indexer) verify that a payment was
  # opened through rail0-api without a shared secret.  Any +paymentId+ that
  # fails the check is silently skipped by the indexer.
  #
  # @return [String] 66-char hex string, e.g. "0xabcd…"
  def self.generate_payment_id
    payload  = SecureRandom.bytes(28)
    checksum = Digest::SHA256.digest(payload)[-4..]
    "0x" + (checksum + payload).unpack1("H*")
  end
end
