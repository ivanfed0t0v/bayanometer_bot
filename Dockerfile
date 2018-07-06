FROM ruby:alpine

RUN mkdir /app
WORKDIR /app

COPY Gemfile ./Gemfile
COPY Gemfile.lock ./Gemfile.lock

RUN bundle install -j 5

COPY ./bayanometer_bot.rb ./bayanometer_bot.rb

ENTRYPOINT ["ruby", "/app/bayanometer_bot.rb"]
