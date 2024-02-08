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
ENV POETRY_VERSION=1.6.1
ENV POETRY_VIRTUALENVS_IN_PROJECT=true
ENV POETRY_NO_INTERACTION=1

# path
ENV VENV="/opt/venv"
ENV PATH="$POETRY_HOME/bin:$VENV/bin:$PATH"

WORKDIR /app

COPY requirements.txt .
COPY . .

RUN python -m venv $VENV \
    && . "${VENV}/bin/activate"\
    && python -m pip install "poetry==${POETRY_VERSION}" \
    && python -m pip install -r requirements.txt

RUN pip install --no-cache-dir /app

# full semver just for python base image
ARG PYTHON_VERSION=3.11.6

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
    && chown -R ${USER_NAME}:${USER_GROUP} ${HOME}

WORKDIR /app

COPY --from=builder --chown=appuser:appuser /app /app
COPY --from=builder --chown=${USER_NAME}:${USER_GROUP} $VENV $VENV

ENV PATH=$VENV_PATH/bin:$HOME/.local/bin:$PATH

USER ${USER_NAME}

CMD ["sleep", "infinity"]
