FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y curl gawk bash && \
    rm -rf /var/lib/apt/lists/*

COPY scripts/check_urls.sh /check_urls.sh
RUN chmod +x /check_urls.sh

ENTRYPOINT ["/check_urls.sh"]
