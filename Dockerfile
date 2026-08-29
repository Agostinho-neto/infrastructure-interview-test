FROM node:24-bookworm-slim AS base

WORKDIR /app

RUN corepack enable \
    && corepack prepare yarn@1.22.22 --activate


FROM base AS build

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

COPY tsconfig.json ./
COPY src ./src

RUN yarn tsc


FROM base AS runtime

ENV NODE_ENV=production

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --production=true \
    && yarn cache clean

COPY --from=build --chown=node:node /app/src ./src

USER node

EXPOSE 3000

CMD ["node", "src/index.js"]