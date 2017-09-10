class BotsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:webhook]

  def index
  end

  def validate
    #puts params["hub.mode"]
    if params["hub.mode"] == "subscribe" && params["hub.verify_token"] == ENV["VERIFY_TOKEN"]
      puts "Validating webhook"
      render plain: params["hub.challenge"], status: 200
    else
      puts "Failed validation. Make sure the validation tokens match."
      render plain: "Forbidden", status: 403
    end
  end

  def webhook
    if params["object"] == "page"
      params["entry"].each do |entry|
        page_id = entry["id"]
        time_of_event = entry["time"]
        entry["messaging"].each do |event|
          if event["message"]
            received_message(event)
          elsif event["postback"]
            received_postback(event)
          else
            puts "Webhook received unknown event: #{event}"
          end
        end
      end
    end
    render plain: "success", status: 200
  end

  def received_message(event)
    sender_id = event["sender"]["id"]
    recipient_id = event["recipient"]["id"]
    time_of_message = event["timestamp"]
    message = event["message"]
    puts "Received message for user #{sender_id} and page #{recipient_id} at #{time_of_message} with message:"
    puts event.to_json

    message_id = message["mid"]
    message_text = message["text"]
    message_attachments = message["attachments"]
    if message_text
      case message_text
      when 'generic'
        send_generic_message(sender_id)
      else
        send_text_message(sender_id,message_text)
      end
    end

  end

  def received_postback(event)
  end

  def send_text_message(recipient_id,message_text)
    # puts "send_text_message"
    message_data = {
      recipient: {
        id: recipient_id
      },
      message: {
        text: message_text
      }
    }
    call_send_api(message_data)
  end

  def send_generic_message(recipient_id)
    puts "generic"
  end

  def call_send_api(message_data)
    page_access_token = ENV["PAGE_ACCESS_TOKEN"]
    RestClient.post("https://graph.facebook.com/v2.6/me/messages?access_token=#{page_access_token}", message_data.to_json, {content_type: :json, accept: :json}){ |response, request, result|
      case response.code
      when 200
        puts "Successfully sent generic message #{response.body}"
      else
        puts "Unable to send message."
        puts response.to_json
      end
    }

  end
end
