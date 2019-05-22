# Base container that is used for both building and running the app
FROM fedora:30 as base
ARG RUBY_MODULE="ruby:2.6"

RUN \
  echo "tsflags=nodocs" >> /etc/dnf/dnf.conf && \
#  dnf -y upgrade && \
  dnf -y module install ${RUBY_MODULE} && \
  dnf -y install ruby{,gems} rubygem-{rake,bundler} hostname sudo wget && \
  dnf clean all && \
  rm -rf /var/cache/dnf/

ARG HOME=/home/foreman-proxy
WORKDIR $HOME
RUN groupadd -r foreman-proxy -f -g 1001 && \
    useradd -u 1001 -r -g foreman-proxy -d $HOME -s /sbin/nologin \
    -c "Foreman Proxy daemon user" foreman-proxy && \
    chown -R 1001:1001 $HOME

# Add a script to be executed every time the container starts.
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Temp container that download gems/npms and compile assets etc
FROM base as builder

ENV BUNDLER_SKIPPED_GROUPS="libvirt windows development test journald puppet_proxy_legacy krb5"
RUN \
  dnf -y install redhat-rpm-config git libsq3-devel \
    gcc-c++ make ruby-devel systemd-devel && \
  dnf clean all && \
  rm -rf /var/cache/dnf/

ARG HOME=/home/foreman-proxy
USER foreman-proxy
WORKDIR $HOME
COPY --chown=1001:1001 . ${HOME}/
RUN bundle install --without "${BUNDLER_SKIPPED_GROUPS}" \
    --binstubs --clean --path vendor --jobs=5 --retry=3 && \
  rm -rf vendor/ruby/*/cache/*.gem && \
  find vendor/ruby/*/gems -name "*.c" -delete && \
  find vendor/ruby/*/gems -name "*.o" -delete

FROM base

ARG HOME=/home/foreman-proxy

USER 1001
WORKDIR ${HOME}
COPY --chown=1001:1001 . ${HOME}/
COPY --from=builder /usr/bin/entrypoint.sh /usr/bin/entrypoint.sh
COPY --from=builder --chown=1001:1001 ${HOME}/.bundle/config ${HOME}/.bundle/config
COPY --from=builder --chown=1001:1001 ${HOME}/Gemfile.lock ${HOME}/Gemfile.lock
COPY --from=builder --chown=1001:1001 ${HOME}/vendor/ruby ${HOME}/vendor/ruby

RUN date -u > BUILD_TIME

# Start the main process.
CMD "bundle exec smart-proxy"

EXPOSE 8000/tcp
