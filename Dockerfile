# syntax=docker/dockerfile:1.6

ARG VERSION=v2.8.0

FROM certbot/certbot:$VERSION as builder

# pip env vars
ENV PYTHONIOENCODING="UTF-8"
ENV PIP_NO_CACHE_DIR=off
ENV PIP_DISABLE_PIP_VERSION_CHECK=on
ENV PIP_DEFAULT_TIMEOUT=100

# poetry env vars
ENV POETRY_HOME="/opt/poetry"
ENV POETRY_VERSION=1.7.1
ENV POETRY_VIRTUALENVS_IN_PROJECT=true
ENV POETRY_NO_INTERACTION=1

# path
ENV VENV="/opt/venv"
ENV PATH="$POETRY_HOME/bin:$VENV/bin:$PATH"

RUN apk add gcc libffi-dev musl-dev --no-cache

WORKDIR /app

COPY requirements.txt .
COPY . .

RUN python -m venv $VENV \
    && . "${VENV}/bin/activate" \
    && python -m pip install --upgrade pip setuptools wheel \
    && python -m pip install cffi --no-cache-dir \
    && python -m pip install "poetry==${POETRY_VERSION}" --no-cache-dir \
    && python -m pip install -r requirements.txt --no-cache-dir

RUN pip install --no-cache-dir /app

# full semver just for python base image
ARG PYTHON_VERSION=3.10.6

FROM certbot/certbot:$VERSION as runner

# setup standard non-root user for use downstream
ENV USER_NAME=appuser
ENV USER_GROUP=appuser
ENV HOME="/home/${USER_NAME}"
ENV HOSTNAME="${HOST:-localhost}"
ENV VENV="/opt/venv"

ENV PATH="${VENV}/bin:${VENV}/lib/python${PYTHON_VERSION}/site-packages:/usr/local/bin:${HOME}/.local/bin:/bin:/usr/bin:/usr/share/doc:$PATH"

# standardise on locale, don't generate .pyc, enable tracebacks on seg faults
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONFAULTHANDLER 1

RUN apk add --no-cache tzdata

ENV TZ=UTC

# create non-root user
RUN addgroup -g 1000 -S ${USER_GROUP} \
    && adduser -u 1000 -S ${USER_NAME} -G ${USER_GROUP} \
    && mkdir -p ${HOME} \
    && mkdir -p /etc/letsencrypt \
    && mkdir -p /var/lib/letsencrypt \
    && mkdir -p /var/log/letsencrypt \
    && chown -R ${USER_NAME}:${USER_GROUP} ${HOME} \
    && chown -R ${USER_NAME}:${USER_GROUP} /etc/letsencrypt \
    && chown -R ${USER_NAME}:${USER_GROUP} /var/lib/letsencrypt \
    && chown -R ${USER_NAME}:${USER_GROUP} /var/log/letsencrypt

COPY --from=builder --chown=${USER_NAME}:${USER_GROUP} $VENV $VENV

ENV PATH=$VENV_PATH/bin:$HOME/.local/bin:$PATH

WORKDIR /app

# ! works but better to mount at runtime
# COPY --chown=${USER_NAME}:${USER_GROUP} credentials.ini .
# RUN chmod 600 credentials.ini

USER ${USER_NAME}

ARG ACME_DEV_URL="https://acme-staging-v02.api.letsencrypt.org/directory"
ARG ACME_PROD_URL="https://acme-v02.api.letsencrypt.org/directory"

# RUN ["sleep", "infinity"]
