FROM node:8 as frontend
WORKDIR /src
ADD . /src
RUN yarn install

FROM ruby:2.4
WORKDIR /app
COPY --from=frontend /src .
RUN bundle install

EXPOSE 3000

CMD bundle exec puma -p 3000
