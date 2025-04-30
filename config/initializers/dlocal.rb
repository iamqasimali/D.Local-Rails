DLOCAL_CONFIG = {
  merchant_id: ENV['DLOCAL_MERCHANT_ID'],
  api_key: ENV['DLOCAL_API_KEY'],
  api_url: ENV['DLOCAL_API_URL'] || 'https://api.dlocal.com'
}.freeze