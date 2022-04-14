# base node image
FROM node:16-bullseye-slim as base

# set for base and all layer that inherit from it
ENV NODE_ENV production

# Install openssl for Prisma
RUN apt-get update && apt-get install -y openssl

# Install all node_modules, including dev dependencies
FROM base as deps

WORKDIR /myapp

ADD .yarn/releases ./.yarn/releases
ADD package.json yarn.lock .yarnrc.yml ./
RUN yarn install --immutable

# Setup production node_modules
FROM base as production-deps

WORKDIR /myapp

COPY --from=deps /myapp /myapp

# Build the app
FROM base as build

WORKDIR /myapp

COPY --from=deps /myapp/node_modules /myapp/node_modules
COPY --from=deps /myapp/.yarn /myapp/.yarn

ADD prisma package.json ./
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
