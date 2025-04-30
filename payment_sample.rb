
require 'openssl'
require 'net/http'
require 'uri'
require 'json'
require 'time'

# Define your credentials and values
secret_key = ''        # Replace with your secret key from dLocal
x_login = ''              # Replace with your X-Login
x_date = Time.now.utc.iso8601         # Get the current UTC date in ISO8601 format
x_trans_key = ''  # Replace with your   X-Trans-Key
request_body = {
  "amount": 1000,
  "currency": "COP",
  "country": "CO",
  "payment_method_id": "CARD",
  "payment_method_flow": "DIRECT",
  "payer": {
    "name": "Camilo Jaramillo",
    "email": "alberto@dlocal.com",
    "document": "1095000000",
    "phone": "4832695335",
    "address": {
      "country": "CO",
      "state": "Antioquia",
      "city": "Envigado",
      "zip_code": "05021",
      "street": "Calle Falsa 123",
      "number": "5940"
    }
  },
  "card": {
    "holder_name": "Camilo Jaramillo",
    "number": "4111111111111111",
    "cvv": "123",
    "expiration_month": 10,
    "expiration_year": 2040,
    "capture": "true"
  },
  "order_id": "ABC123456",
  "description": "Food and groceries",
  "notification_url": "https://merchant-site.com/notification"
}.to_json                             # Example request body

# Step 1: Generate the signature (HMAC-SHA256)
def generate_signature(secret_key, x_login, x_date, request_body)
  data = "#{x_login}#{x_date}#{request_body}"
  OpenSSL::HMAC.hexdigest('sha256', secret_key, data)
end

signature = generate_signature(secret_key, x_login, x_date, request_body)

# Step 2: Set the Authorization header
authorization_header = "V2-HMAC-SHA256, Signature: #{signature}"

# Step 3: Prepare headers for the API request
headers = {
  'X-Date' => x_date,
  'X-Login' => x_login,
  'X-Trans-Key' => '',  # Replace with your X-Trans-Key
  'Content-Type' => 'application/json',
  'X-Version' => '2.1',
  'User-Agent' => 'MerchantTest / 1.0',  # Adjust as needed
  'Authorization' => authorization_header
}

# Log headers for debugging purposes
puts "Request Headers:"
headers.each { |key, value| puts "#{key}: #{value}" }

# Step 4: Set up the HTTP client and configure timeouts

# https://sandbox.dlocal.com
url = URI.parse('https://sandbox.dlocal.com/secure_payments')

# url = URI.parse('https://api.dlocal.com/payments')
http = Net::HTTP.new(url.host, url.port)

# Set timeouts (10 seconds for both open and read)
http.open_timeout = 10  # seconds
http.read_timeout = 10  # seconds

# Optional: Disable SSL verification for testing purposes (not recommended for production)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE  # Disable SSL verification for testing only

# Step 5: Retry mechanism for handling ECONNRESET errors
max_retries = 3
retries = 0
begin
  # Prepare the request
  request = Net::HTTP::Post.new(url.path, headers)
  request.body = request_body

  # Send the request
  response = http.request(request)

  # Step 6: Handle the response
  puts "Response Code: #{response.code}"
  puts "Response Body: #{response.body}"

rescue Errno::ECONNRESET => e
  retries += 1
  if retries <= max_retries
    puts "Connection reset by peer. Retrying... (Attempt #{retries} of #{max_retries})"
    retry
  else
    puts "Max retries reached. Error: #{e.message}"
  end
rescue StandardError => e
  # Handle other errors
  puts "An error occurred: #{e.message}"
end

