RSpec.describe Rail0::Client do
  let(:client) { Rail0::Client.new(base_url: BASE_URL) }

  def stub_get(path, body, status: 200)
    stub_request(:get, "#{BASE_URL}#{path}")
      .to_return(status:, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_post(path, body, status: 200)
    stub_request(:post, "#{BASE_URL}#{path}")
      .to_return(status:, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  def stub_put(path, body, status: 200)
    stub_request(:put, "#{BASE_URL}#{path}")
      .to_return(status:, body: body.to_json, headers: { "Content-Type" => "application/json" })
  end

  # ================================================================
  #  payments.create — POST /payments
  # ================================================================

  describe "payments.create" do
    it "returns a payment intent with signingPayload" do
      response = {
        paymentId:      PAYMENT_ID,
        configHash:     "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
        payment:        PAYMENT_INPUT.merge(authorizationExpiry: 9_999_999_999, refundExpiry: 9_999_999_999, feeBps: 0, feeReceiver: "0x0000000000000000000000000000000000000000"),
        chainId:        84532,
        rail0Contract:  "0xRail0Contract0000000000000000000000000000",
        signingPayload: { domain: {}, types: {}, primaryType: "TransferWithAuthorization", message: {} }
      }
      stub_post("/payments", response, status: 201)

      result = client.payments.create(payment: PAYMENT_INPUT, chainId: 84532, mode: "authorize")

      expect(result[:paymentId]).to eq(PAYMENT_ID)
      expect(result[:signingPayload]).to be_a(Hash)
    end
  end

  # ================================================================
  #  payments.get — GET /payments/{id}
  # ================================================================

  describe "payments.get" do
    it "returns current payment state" do
      stub_get("/payments/#{PAYMENT_ID}", PAYMENT_RESPONSE)

      result = client.payments.get(PAYMENT_ID)

      expect(result[:paymentId]).to eq(PAYMENT_ID)
      expect(result[:status]).to eq("authorized")
      expect(result[:onChain][:exists]).to be(true)
      expect(result[:onChain][:capturableAmount]).to eq("100000000")
    end
  end

  # ================================================================
  #  payments.sign — PUT /payments/{id}/sign
  # ================================================================

  describe "payments.sign" do
    it "stores the payer signature and returns recoveredPayer" do
      stub_put("/payments/#{PAYMENT_ID}/sign", SIGN_RESPONSE)

      result = client.payments.sign(PAYMENT_ID, {
        signature: "0x" + "ab" * 65
      })

      expect(result[:status]).to eq("signature_stored")
      expect(result[:recoveredPayer]).to eq(PAYMENT_INPUT[:payer])
    end
  end

  # ================================================================
  #  payments.prepare_authorize — POST /payments/{id}/authorize
  # ================================================================

  describe "payments.prepare_authorize" do
    it "returns an unsigned transaction" do
      stub_post("/payments/#{PAYMENT_ID}/authorize", PREPARE_RESPONSE)

      result = client.payments.prepare_authorize(PAYMENT_ID)

      expect(result[:unsignedTransaction]).to eq(PREPARE_RESPONSE[:unsignedTransaction])
      expect(result[:gasLimit]).to eq("200000")
    end
  end

  # ================================================================
  #  payments.prepare_charge — POST /payments/{id}/charge
  # ================================================================

  describe "payments.prepare_charge" do
    it "returns an unsigned charge transaction" do
      stub_post("/payments/#{PAYMENT_ID}/charge", PREPARE_RESPONSE)

      result = client.payments.prepare_charge(PAYMENT_ID)

      expect(result[:unsignedTransaction]).to eq(PREPARE_RESPONSE[:unsignedTransaction])
    end
  end

  # ================================================================
  #  payments.prepare_capture — POST /payments/{id}/capture
  # ================================================================

  describe "payments.prepare_capture" do
    it "returns an unsigned capture transaction" do
      stub_post("/payments/#{PAYMENT_ID}/capture", PREPARE_RESPONSE)

      result = client.payments.prepare_capture(PAYMENT_ID, { amount: "100000000" })

      expect(result[:chainId]).to eq(84532)
    end
  end

  # ================================================================
  #  payments.prepare_void — POST /payments/{id}/void
  # ================================================================

  describe "payments.prepare_void" do
    it "returns an unsigned void transaction" do
      stub_post("/payments/#{PAYMENT_ID}/void", PREPARE_RESPONSE)

      result = client.payments.prepare_void(PAYMENT_ID)

      expect(result[:nonce]).to eq(42)
    end
  end

  # ================================================================
  #  payments.prepare_release — POST /payments/{id}/release
  # ================================================================

  describe "payments.prepare_release" do
    it "returns an unsigned release transaction" do
      stub_post("/payments/#{PAYMENT_ID}/release", PREPARE_RESPONSE)

      result = client.payments.prepare_release(PAYMENT_ID)

      expect(result[:to]).to eq(PREPARE_RESPONSE[:to])
    end

    it "accepts an optional callerAddress" do
      stub_post("/payments/#{PAYMENT_ID}/release", PREPARE_RESPONSE)

      result = client.payments.prepare_release(PAYMENT_ID, { callerAddress: PAYMENT_INPUT[:payer] })

      expect(result[:unsignedTransaction]).to eq(PREPARE_RESPONSE[:unsignedTransaction])
    end
  end

  # ================================================================
  #  payments.prepare_approve — POST /payments/{id}/approve
  # ================================================================

  describe "payments.prepare_approve" do
    it "returns an unsigned ERC-20 approve transaction" do
      stub_post("/payments/#{PAYMENT_ID}/approve", PREPARE_RESPONSE)

      result = client.payments.prepare_approve(PAYMENT_ID, { amount: "115792089237316195423570985008687907853269984665640564039457584007913129639935" })

      expect(result[:data]).to eq(PREPARE_RESPONSE[:data])
    end
  end

  # ================================================================
  #  payments.prepare_refund — POST /payments/{id}/refund
  # ================================================================

  describe "payments.prepare_refund" do
    it "returns an unsigned refund transaction" do
      stub_post("/payments/#{PAYMENT_ID}/refund", PREPARE_RESPONSE)

      result = client.payments.prepare_refund(PAYMENT_ID, { amount: "50000000" })

      expect(result[:gasLimit]).to eq("200000")
    end
  end

  # ================================================================
  #  payments.submit_transaction — POST /payments/{id}/transactions/submit
  # ================================================================

  describe "payments.submit_transaction" do
    it "returns 202 with status submitting" do
      stub_post("/payments/#{PAYMENT_ID}/transactions/submit", SUBMIT_RESPONSE, status: 202)

      result = client.payments.submit_transaction(PAYMENT_ID, {
        signedTransaction: "0x02f8ab1234"
      })

      expect(result[:paymentId]).to eq(PAYMENT_ID)
      expect(result[:status]).to eq("submitting")
    end
  end

  # ================================================================
  #  merchants.payment_methods — GET /merchants/{id}/payment-methods
  # ================================================================

  describe "merchants.payment_methods" do
    it "returns a list of accepted payment methods" do
      stub_get("/merchants/#{MERCHANT_ID}/payment-methods", [PAYMENT_METHOD])

      result = client.merchants.payment_methods(MERCHANT_ID)

      expect(result).to be_an(Array)
      expect(result.first[:tokenSymbol]).to eq("USDC")
      expect(result.first[:isDefault]).to be(true)
    end
  end

  # ================================================================
  #  Error handling
  # ================================================================

  describe "error handling" do
    it "raises Rail0::ApiError on 422 (payment not found)" do
      stub_get("/payments/#{PAYMENT_ID}",
               { error: "payment_not_found", message: "No payment exists for the given paymentId." },
               status: 422)

      expect { client.payments.get(PAYMENT_ID) }
        .to raise_error(Rail0::ApiError) do |err|
          expect(err.status).to eq(422)
          expect(err.error).to eq("payment_not_found")
          expect(err.message).to include("No payment exists")
        end
    end

    it "raises Rail0::ApiError on 400 (missing fields)" do
      stub_post("/payments/#{PAYMENT_ID}/capture",
                { error: "missing_amount", message: "amount is required." },
                status: 400)

      expect { client.payments.prepare_capture(PAYMENT_ID, {}) }
        .to raise_error(Rail0::ApiError) do |err|
          expect(err.status).to eq(400)
          expect(err.error).to eq("missing_amount")
        end
    end

    it "raises Rail0::ApiError on 422 (wrong payment state for submit)" do
      stub_post("/payments/#{PAYMENT_ID}/transactions/submit",
                { error: "no_pending_operation", message: "No prepare step was called yet." },
                status: 422)

      expect do
        client.payments.submit_transaction(PAYMENT_ID, { signedTransaction: "0x02f8ab" })
      end.to raise_error(Rail0::ApiError) do |err|
        expect(err.status).to eq(422)
        expect(err.error).to eq("no_pending_operation")
      end
    end
  end

  # ================================================================
  #  Logging
  # ================================================================

  describe "logging" do
    it "calls the logger with a LogEntry on success" do
      entries = []
      logged_client = Rail0::Client.new(base_url: BASE_URL, logger: ->(e) { entries << e })
      stub_get("/payments/#{PAYMENT_ID}", PAYMENT_RESPONSE)

      logged_client.payments.get(PAYMENT_ID)

      expect(entries.size).to eq(1)
      entry = entries.first
      expect(entry.method).to eq("GET")
      expect(entry.status).to eq(200)
      expect(entry.error).to be_nil
    end

    it "calls the logger with error on API failure" do
      entries = []
      logged_client = Rail0::Client.new(base_url: BASE_URL, logger: ->(e) { entries << e })
      stub_get("/payments/#{PAYMENT_ID}",
               { error: "payment_not_found", message: "Not found." },
               status: 422)

      expect { logged_client.payments.get(PAYMENT_ID) }.to raise_error(Rail0::ApiError)

      expect(entries.size).to eq(1)
      expect(entries.first.error).to be_a(Rail0::ApiError)
    end

    it "DEBUG_LOGGER writes to stdout" do
      stub_get("/payments/#{PAYMENT_ID}", PAYMENT_RESPONSE)
      logged_client = Rail0::Client.new(base_url: BASE_URL, logger: Rail0::DEBUG_LOGGER)

      expect { logged_client.payments.get(PAYMENT_ID) }.to output(/\[rail0\]/).to_stdout
    end
  end

  # ================================================================
  #  Retry
  # ================================================================

  describe "retry" do
    it "retries on network errors and succeeds" do
      attempt = 0
      stub_request(:get, "#{BASE_URL}/payments/#{PAYMENT_ID}").to_return do
        attempt += 1
        if attempt < 3
          raise SocketError, "connection refused"
        else
          { status: 200, body: PAYMENT_RESPONSE.to_json, headers: { "Content-Type" => "application/json" } }
        end
      end

      retrying_client = Rail0::Client.new(base_url: BASE_URL, max_retries: 2, retry_delay: 0)
      result = retrying_client.payments.get(PAYMENT_ID)

      expect(result[:paymentId]).to eq(PAYMENT_ID)
      expect(attempt).to eq(3)
    end

    it "does not retry HTTP errors" do
      attempts = 0
      stub_request(:get, "#{BASE_URL}/payments/#{PAYMENT_ID}").to_return do
        attempts += 1
        { status: 422, body: { error: "payment_not_found", message: "Not found." }.to_json,
          headers: { "Content-Type" => "application/json" } }
      end

      retrying_client = Rail0::Client.new(base_url: BASE_URL, max_retries: 2, retry_delay: 0)

      expect { retrying_client.payments.get(PAYMENT_ID) }.to raise_error(Rail0::ApiError)
      expect(attempts).to eq(1)
    end
  end
end
