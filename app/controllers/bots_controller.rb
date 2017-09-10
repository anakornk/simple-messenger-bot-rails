class BotsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:webhook]

  # Display the web page
  def index
  end

  # Webhook validation
  def validate
    # puts params["hub.mode"]
    if params["hub.mode"] == "subscribe" && params["hub.verify_token"] == ENV["VERIFY_TOKEN"]
      puts "Validating webhook"
      render plain: params["hub.challenge"], status: 200
    else
      puts "Failed validation. Make sure the validation tokens match."
      render plain: "Forbidden", status: 403
    end
  end

  # Message processing
  def webhook
    # Make sure this is a page subscription
    if params["object"] == "page"
      # Iterate over each entry - there may be multiple if batched
      params["entry"].each do |entry|
        page_id = entry["id"]
        time_of_event = entry["time"]
        # Iterate over each messaging event
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
    # Assume all went well.
    #
    # You must send back a 200, within 20 seconds, to let us know
    # you've successfully received the callback. Otherwise, the request
    # will time out and we will keep trying to resend.
    render plain: "success", status: 200
  end

  # Incoming events handling
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
      # If we receive a text message, check to see if it matches a keyword
      # and send back the template example. Otherwise, just echo the text we received.
      case message_text
      when 'generic'
        send_generic_message(sender_id)
      else
        send_text_message(sender_id,message_text)
      end
    end

  end

  def received_postback(event)
    sender_id = event["sender"]["id"]
    recipient_id = event["recipient"]["id"]
    time_of_postback = event["timestamp"]

    # The 'payload' param is a developer-defined field which is set in a postback
    # button for Structured Messages.
    payload = event["postback"]["payload"]

    puts "Received postback for user #{sender_id} and page #{recipient_id} with payload '#{payload}' at #{time_of_postback}"

    # When a postback is called, we'll send a message back to the sender to
    # let them know it was successful
    send_text_message(sender_id, "Postback called")
  end

  ###################
  # Sending helpers #
  ###################

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
    # puts "generic"
    message_data = {
      recipient: {
        id: recipient_id
      },
      message: {
        attachment: {
          type: "template",
          payload: {
            template_type: "generic",
            elements: [{
              title: "rift",
              subtitle: "Next-generation virtual reality",
              item_url: "https://www.oculus.com/en-us/rift/",
              image_url: "http://messengerdemo.parseapp.com/img/rift.png",
              buttons: [{
                type: "web_url",
                url: "https://www.oculus.com/en-us/rift/",
                title: "Open Web URL"
              }, {
                type: "postback",
                title: "Call Postback",
                payload: "Payload for first bubble",
              }],
            }, {
              title: "touch",
              subtitle: "Your Hands, Now in VR",
              item_url: "https://www.oculus.com/en-us/touch/",
              image_url: "http://messengerdemo.parseapp.com/img/touch.png",
              buttons: [{
                type: "web_url",
                url: "https://www.oculus.com/en-us/touch/",
                title: "Open Web URL"
              }, {
                type: "postback",
                title: "Call Postback",
                payload: "Payload for second bubble",
              }]
            }]
          }
        }
      }
    }
    call_send_api(message_data)
  end

  def call_send_api(message_data)
    page_access_token = ENV["PAGE_ACCESS_TOKEN"]
    RestClient.post("https://graph.facebook.com/v2.6/me/messages?access_token=#{page_access_token}", message_data.to_json, {content_type: :json, accept: :json}){ |response, request, result|
      case response.code
      when 200
        body_hash = JSON.parse(response.body)
        recipient_id = body_hash["recipient_id"]
        message_id = body_hash["message_id"]
        puts "Successfully sent generic message with id #{message_id} to recipient #{recipient_id}"
      else
        puts "Unable to send message."
        puts response.to_json
      end
    }

  end
end
