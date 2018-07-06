#/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'redis'
require 'telegram/bot'
require 'digest'
require 'open-uri'
require 'logger'


def added_to_the_new_chat(bot, chat_id)
    bot.api.send_message(chat_id: chat_id, text: "Дратути!")
    bot.api.send_message(chat_id: chat_id, text: "Да начнутся голодные игры!")
    # TODO: add history parsing
end

log = Logger.new( 'logs/bayanometer_log.txt', 'daily' )
log.level = Logger::DEBUG

bot_auth_token = ENV["BAYANOMETER_AUTH_TOKEN"]

# TODO: use web hooks
Telegram::Bot::Client.run(bot_auth_token) do |bot|

    # Connection parameters are specified in REDIS_URL variable
    redis = Redis.new()

    me = bot.api.getMe()
    my_id = me['result']['id']
    my_username = me['result']['username']

    bot.listen do |message|
        if !message.new_chat_members.empty?
            log.info "Recieved notification about a new member."
            for member in message.new_chat_members
                if member.id = my_id
                    log.info "I was added to the new chat."
                    added_to_the_new_chat(bot, message.chat.id)
                end
            end
        end

        # TODO: also check if url in the message is an image.
        if !message.photo.empty?
            log.info "Received message with an image."
            max_height = 0
            max_width = 0

            log.debug "Searching for the largest available image size."
            for image in message.photo
                if image.width > max_width or image.height > max_height
                    max_width = image.width
                    max_height = image.height
                    max_image_id = image.file_id
                end
            end

            log.debug "Getting image download url."
            remote_image_path = bot.api.getFile(file_id: max_image_id)['result']['file_path']
            image_url = "https://api.telegram.org/file/bot#{bot_auth_token}/#{remote_image_path}"

            log.debug "Calculating image hashsum."
            image_contents = open(image_url).read
            hash = Digest::SHA256.hexdigest(image_contents)
            log.debug "Hashsum successfully calculated: " + hash

            key = message.chat.id.to_s + ":" + hash
            if redis.exists(key)
                log.info "Received image is bayan, notifying everyone."
                bot.api.send_message(chat_id: message.chat.id, text: "БАЯН!!!")
                bot.api.send_message(chat_id: message.chat.id, text: "УДОЛИ БЫСТРО")
                # TODO: repost the original message
            else
                log.info "Received image is original, saving info to the db."
                redis.hmset(key, "message_id", message.message_id, "sender_id", message.from.id, "date", message.date)
            end
        end
    end
end
