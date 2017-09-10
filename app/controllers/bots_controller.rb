class BotsController < ApplicationController
  def index
  end

  def validate
    #puts params["hub.mode"]
    if params["hub.mode"] == "subscribe" && params["hub.verify_token"] == "tatatata"
      puts "Validating webhook"
      render plain: params["hub.challenge"], status: 200
    else
      puts "Failed validation. Make sure the validation tokens match."
      render plain: "Forbidden", status: 403
    end
  end

  def webhook
  end
end
