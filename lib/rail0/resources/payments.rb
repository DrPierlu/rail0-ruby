# frozen_string_literal: true

module Rail0
  module Resources
    class Payments
      def initialize(http)
        @http = http
      end

      # Create a payment intent. Returns the EIP-712 signingPayload for the payer to sign.
      # @param params [Hash] CreatePaymentRequest: payment (PaymentInput), chainId, mode
      # @return [Hash] CreatePaymentResponse: paymentId, configHash, payment, chainId, rail0Contract, signingPayload
      def create(params)
        @http.post("/payments", params)
      end

      # Fetch current payment state (DB status + live on-chain amounts when applicable).
      # Poll this after #submit_transaction until status leaves `submitting`.
      # @param payment_id [String] bytes32 payment identifier
      # @return [Hash] GetPaymentResponse: paymentId, status, mode, amount, payer, payee, token,
      #   chainId, authorizationExpiry, refundExpiry, onChain (optional), lastTxHash (optional),
      #   failureCode (optional), failureMessage (optional)
      def get(payment_id)
        @http.get("/payments/#{payment_id}")
      end

      # Submit the payer's EIP-712 signature over the signingPayload.
      # @param payment_id [String] bytes32 payment identifier
      # @param params [Hash] PayerSignatureRequest: signature (65-byte hex, 0x-prefixed, 132 chars)
      # @return [Hash] PayerSignatureResponse: paymentId, status, recoveredPayer
      def sign(payment_id, params)
        @http.put("/payments/#{payment_id}/sign", params)
      end

      # Prepare the unsigned authorize() transaction. Called by the payee.
      # Requires the payer's signature to have been stored via #sign.
      # @param payment_id [String]
      # @return [Hash] PrepareTransactionResponse: unsignedTransaction, to, data, chainId, nonce,
      #   maxFeePerGas, maxPriorityFeePerGas, gasLimit
      def prepare_authorize(payment_id)
        @http.post("/payments/#{payment_id}/authorize")
      end

      # Prepare the unsigned charge() transaction (one-shot authorize+capture). Called by the payee.
      # Requires the payer's signature (mode=charge) to have been stored via #sign.
      # @param payment_id [String]
      # @return [Hash] PrepareTransactionResponse
      def prepare_charge(payment_id)
        @http.post("/payments/#{payment_id}/charge")
      end

      # Prepare the unsigned capture() transaction. Called by the payee.
      # Partial captures are supported: amount may be less than capturableAmount.
      # @param payment_id [String]
      # @param params [Hash] CapturePaymentRequest: amount (Uint256String)
      # @return [Hash] PrepareTransactionResponse
      def prepare_capture(payment_id, params)
        @http.post("/payments/#{payment_id}/capture", params)
      end

      # Prepare the unsigned void() transaction. Called by the payee.
      # Cancels the authorization and returns all escrowed funds to the payer.
      # @param payment_id [String]
      # @return [Hash] PrepareTransactionResponse
      def prepare_void(payment_id)
        @http.post("/payments/#{payment_id}/void")
      end

      # Prepare the unsigned refund() transaction. Called by the payee.
      # Requires an active ERC-20 allowance — call #prepare_approve first if needed.
      # @param payment_id [String]
      # @param params [Hash] RefundPaymentRequest: amount (Uint256String)
      # @return [Hash] PrepareTransactionResponse
      def prepare_refund(payment_id, params)
        @http.post("/payments/#{payment_id}/refund", params)
      end

      # Prepare the unsigned release() transaction. Called by the payer or payee.
      # Returns all remaining escrowed funds to the payer.
      # @param payment_id [String]
      # @param params [Hash] ReleaseRequest (optional): callerAddress
      # @return [Hash] PrepareTransactionResponse
      def prepare_release(payment_id, params = {})
        @http.post("/payments/#{payment_id}/release", params)
      end

      # Prepare the unsigned ERC-20 approve() transaction needed before a refund. Called by the payee.
      # @param payment_id [String]
      # @param params [Hash] ApproveRequest: amount (Uint256String)
      # @return [Hash] PrepareTransactionResponse
      def prepare_approve(payment_id, params)
        @http.post("/payments/#{payment_id}/approve", params)
      end

      # Broadcast a signed transaction on-chain (async). Returns HTTP 202 immediately.
      # The operation is inferred server-side from the preceding prepare step.
      # Poll #get until status leaves `submitting` to get the final outcome.
      # @param payment_id [String]
      # @param params [Hash] SubmitTransactionRequest: signedTransaction (RLP-encoded signed tx)
      # @return [Hash] SubmitTransactionAcceptedResponse: paymentId, status ("submitting")
      def submit_transaction(payment_id, params)
        @http.post("/payments/#{payment_id}/transactions/submit", params)
      end
    end
  end
end
