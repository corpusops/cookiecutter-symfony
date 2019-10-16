FROM cypress/base:10

WORKDIR /app

# dependencies will be installed only if the package files change
COPY package.json .
COPY package-lock.json .

# by setting CI environment variable we switch the Cypress install messages
# to small "started / finished" and avoid 1000s of lines of progress messages
# https://github.com/cypress-io/cypress/issues/1243
ENV CI=1
# RUN npm install
RUN npm ci
# verify that Cypress has been installed correctly.
# running this command separately from "cypress run" will also cache its result
# to avoid verifying again when running the tests
RUN npx cypress verify

# If you want to launch e2e tests on systems built via docker-compose
# you may need to enable dockerize to wait for everyhting to be up
# ENV DOCKERIZE_VERSION v0.6.1
# RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
#     && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz \
#     && rm dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

# alter startup to add dynamic absolute app domain DNS resolv
# via /etc/hosts
WORKDIR /
COPY init.sh .
WORKDIR /app
ENTRYPOINT ["/init.sh"]
#CMD "/init.sh"
