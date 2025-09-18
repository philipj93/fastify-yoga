# base node image
FROM node:22-bullseye-slim as base

# set for base and all layer that inherit from it
ENV NODE_ENV production

# Install openssl for Prisma
RUN apt-get update && apt-get install -y openssl

# Install all node_modules, including dev dependencies
FROM base as deps

WORKDIR /myapp

ADD .yarn ./.yarn
ADD package.json .yarnrc.yml yarn.lock ./
RUN yarn install --immutable

# Setup production node_modules
FROM base as production-deps

WORKDIR /myapp

COPY --from=deps /myapp/node_modules /myapp/node_modules
COPY --from=deps /myapp/.yarn/releases /myapp/.yarn/releases
COPY --from=deps /myapp/package.json /myapp/package.json
COPY --from=deps /myapp/.yarnrc.yml /myapp/.yarnrc.yml
COPY --from=deps /myapp/yarn.lock /myapp/yarn.lock

# Build the app
FROM base as build

WORKDIR /myapp

COPY --from=deps /myapp/node_modules /myapp/node_modules
COPY --from=deps /myapp/.yarn /myapp/.yarn
COPY --from=deps /myapp/package.json /myapp/package.json

ADD prisma .
RUN yarn prisma generate

ADD . .
RUN yarn build

# Finally, build the production image with minimal footprint
FROM base

WORKDIR /myapp

COPY --from=production-deps /myapp/node_modules /myapp/node_modules
COPY --from=build /myapp/.yarn /myapp/.yarn
COPY --from=build /myapp/node_modules/.prisma /myapp/node_modules/.prisma

COPY --from=build /myapp/dist /myapp/dist
ADD . .

CMD ["yarn", "start"]
