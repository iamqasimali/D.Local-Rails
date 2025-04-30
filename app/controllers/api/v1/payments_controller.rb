# app/controllers/api/v1/payments_controller.rb
class Api::V1::PaymentsController < Api::V1::BaseApiController

    def create
      return render_error("Missing or invalid parameters") unless valid_payment_params?
  
      dlocal_response = DlocalService.new.create_payment(payment_params)
  
      unless dlocal_response["status"] == "PAID"
        return render_error(dlocal_response[:error], 422)
      end
  
      payment = build_payment_from_response(dlocal_response)
  
      if payment.save
        render json: {
          message: "Payment completed successfully!",
          data: {
            booking_id: payment.booking_id,
            payment_id: payment.id
          },
          code: 200
        }
      else
        render_error(payment.errors.full_messages.to_sentence, 422)
      end
    end
  
    def webhook
      # Verify webhook signature here
      head :ok
    end
  
    private
  
    def payment_params
      params.require(:payment).permit(
        :amount, :currency, :country, :payment_method_id, :order_id, :description, :payment_method_flow,
        payer: [:name, :email, :document, :phone, address: %i[country state city zip_code street number]],
        card: [:holder_name, :number, :cvv, :expiration_month, :expiration_year]
      )
    end
    def valid_payment_params?
      params[:payment] && params[:payment][:booking_id].present? && params[:payment][:amount].present? && params[:payment][:amount].to_f > 0
    end
  
    def build_payment_from_response(response)
      Payment.new(
        booking_id: params[:payment][:booking_id],
        amount: response["amount"],
        payment_method: response["payment_method_type"],
        currency: response["currency"],
        transaction_id: response["id"],
        status: "completed",
        paid_at: response["created_date"],
        user_id: current_user.id,
        payment_id: response["id"],
        card_type: response.dig("card", "brand"),
        card_last4: response.dig("card", "last4"),
        response_data: response
      )
    end
  
    def render_error(message, status = 400)
      render json: { error: message, code: status }, status: status
    end
  
  end