# class Payment < ApplicationRecord {
#                  :id => :integer,
#          :booking_id => :integer,
#      :payment_method => :string,
#              :amount => :decimal,
#            :currency => :string,
#      :transaction_id => :string,
#              :status => :string,
#             :paid_at => :datetime,
#          :created_at => :datetime,
#          :updated_at => :datetime,
#             :user_id => :integer,
#       :refund_amount => :decimal,
#       :refund_reason => :text,
#     :payment_gateway => :string,
#          :payment_id => :string,
#           :card_type => :string,
#          :card_last4 => :string,
#       :response_data => :jsonb
# }

class Payment < ApplicationRecord
    #Relations
    belongs_to :booking
    belongs_to :user
  
    #enums
    enum status: { pending: "pending", completed: "completed", failed: "failed", refunded: "refunded" }
  
    #validations
    validates :amount, :currency, presence: true
  end
  