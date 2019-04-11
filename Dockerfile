# VERSION 1.10.2
# AUTHOR: Matthieu "Puckel_" Roisil
# DESCRIPTION: Basic Airflow container
# BUILD: docker build --rm -t puckel/docker-airflow .
# SOURCE: https://github.com/puckel/docker-airflow

FROM python:3.6-stretch
LABEL maintainer="Puckel_"

# Never prompts the user for choices on installation/configuration of packages
ENV DEBIAN_FRONTEND noninteractive
ENV TERM linux

# Airflow
ARG AIRFLOW_VERSION=1.10.2
ARG AIRFLOW_HOME=/usr/local/airflow
ARG AIRFLOW_DEPS=""
ARG PYTHON_DEPS=""
ENV AIRFLOW_GPL_UNIDECODE yes
ARG R_VERSION
ARG BUILD_DATE


# Define en_US.
ENV LANGUAGE en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LC_CTYPE en_US.UTF-8
ENV LC_MESSAGES en_US.UTF-8
ENV R_VERSION ${R_VERSION:-3.5.3}
ENV TERM xterm
ENV JULIA_PATH /usr/local/julia
ENV PATH $JULIA_PATH/bin:$PATH


RUN set -ex \
    && buildDeps=' \
        freetds-dev \
        libkrb5-dev \
        libsasl2-dev \
        libssl-dev \
        libffi-dev \
        libpq-dev \
        git \
        curl \
        # BUILDDEPS from https://github.com/rocker-org/rocker-versioned/blob/master/r-ver/Dockerfile
        default-jdk \
        libbz2-dev \
        libcairo2-dev \
        libcurl4-openssl-dev \
        libpango1.0-dev \
        libjpeg-dev \
        libicu-dev \
        libpcre3-dev \
        libpng-dev \
        libreadline-dev \
        libtiff5-dev \
        liblzma-dev \
        libx11-dev \
        libxt-dev \
        perl \
        tcl8.6-dev \
        tk8.6-dev \
        texinfo \
        texlive-extra-utils \
        texlive-fonts-recommended \
        texlive-fonts-extra \
        texlive-latex-recommended \
        x11proto-core-dev \
        xauth \
        xfonts-base \
        xvfb \
        zlib1g-dev \
    ' \
    && apt-get update -yqq \
    && apt-get upgrade -yqq \
    && apt-get install -yqq --no-install-recommends \
        $buildDeps \
        freetds-bin \
        build-essential \
        default-libmysqlclient-dev \
        apt-utils \
        curl \
        rsync \
        netcat \
        locales \
    && sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    # install script from https://github.com/rocker-org/rocker-versioned/blob/master/r-ver/Dockerfile
    && apt-get install -y --no-install-recommends \
        bash-completion \
        ca-certificates \
        file \
        fonts-texgyre \
        g++ \
        gfortran \
        gsfonts \
        libblas-dev \
        libbz2-1.0 \
        libcurl3 \
        libicu57 \
        libjpeg62-turbo \
        libopenblas-dev \
        libpangocairo-1.0-0 \
        libpcre3 \
        libpng16-16 \
        libreadline7 \
        libtiff5 \
        liblzma5 \
        locales \
        make \
        unzip \
        zip \
        zlib1g \
    ## install lib myself
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        libblas-dev \
        liblapack-dev \
        libltdl7 \
        unixodbc-dev \
        python3-requests \
        software-properties-common \
    && cd tmp/ \
    ## Download source code
    && curl -O https://cran.r-project.org/src/base/R-3/R-${R_VERSION}.tar.gz \
    ## Extract source code
    && tar -xf R-${R_VERSION}.tar.gz \
    && cd R-${R_VERSION} \
    ## Set compiler flags
    && R_PAPERSIZE=letter \
    R_BATCHSAVE="--no-save --no-restore" \
    R_BROWSER=xdg-open \
    PAGER=/usr/bin/pager \
    PERL=/usr/bin/perl \
    R_UNZIPCMD=/usr/bin/unzip \
    R_ZIPCMD=/usr/bin/zip \
    R_PRINTCMD=/usr/bin/lpr \
    LIBnn=lib \
    AWK=/usr/bin/awk \
    CFLAGS="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -g" \
    CXXFLAGS="-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -Wdate-time -D_FORTIFY_SOURCE=2 -g" \
    ## Configure options
    ./configure --enable-R-shlib \
               --enable-memory-profiling \
               --with-readline \
               --with-blas \
               --with-tcltk \
               --disable-nls \
               --with-recommended-packages \
    ## Build and install
    && make \
    && make install \
    ## Add a default CRAN mirror
    && echo "options(repos = c(CRAN = 'https://cran.rstudio.com/'), download.file.method = 'libcurl')" >> /usr/local/lib/R/etc/Rprofile.site \
    ## Add a library directory (for user-installed packages)
    && mkdir -p /usr/local/lib/R/site-library \
    && chown root:staff /usr/local/lib/R/site-library \
    && chmod g+wx /usr/local/lib/R/site-library \
    ## Fix library path
    && echo "R_LIBS_USER='/usr/local/lib/R/site-library'" >> /usr/local/lib/R/etc/Renviron \
    && echo "R_LIBS=\${R_LIBS-'/usr/local/lib/R/site-library:/usr/local/lib/R/library:/usr/lib/R/library'}" >> /usr/local/lib/R/etc/Renviron \
    ## install packages from date-locked MRAN snapshot of CRAN
    && [ -z "$BUILD_DATE" ] && BUILD_DATE=$(TZ="America/Los_Angeles" date -I) || true \
    && MRAN=https://mran.microsoft.com/snapshot/${BUILD_DATE} \
    && echo MRAN=$MRAN >> /etc/environment \
    && export MRAN=$MRAN \
    && echo "options(repos = c(CRAN='$MRAN'), download.file.method = 'libcurl')" >> /usr/local/lib/R/etc/Rprofile.site \
    ## Use littler installation scripts
    && Rscript -e "install.packages(c('littler', 'docopt'), repo = '$MRAN')" \
    && ln -s /usr/local/lib/R/site-library/littler/examples/install2.r /usr/local/bin/install2.r \
    && ln -s /usr/local/lib/R/site-library/littler/examples/installGithub.r /usr/local/bin/installGithub.r \
    && ln -s /usr/local/lib/R/site-library/littler/bin/r /usr/local/bin/r \
    && R CMD javareconf \
    && curl -fL -o julia.tar.gz "https://julialang-s3.julialang.org/bin/linux/x64/1.1/julia-1.1.0-linux-x86_64.tar.gz" \
    && mkdir "$JULIA_PATH" \
    && tar -xzf julia.tar.gz -C "$JULIA_PATH" --strip-components 1 \
    && rm julia.tar.gz \
    && julia --version \
    && echo "options(JULIA_HOME='$JULIA_PATH/bin/')" >> /usr/local/lib/R/etc/Rprofile.site \
    && curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/debian/9/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get -y install msodbcsql17 \
    && ACCEPT_EULA=Y apt-get -y install mssql-tools \
    && groupadd --gid 119 docker \
    && useradd --shell /bin/bash \
        --create-home \
        --home-dir ${AIRFLOW_HOME} \
        airflow \
    && usermod -aG docker airflow \
    && pip install -U pip setuptools wheel \
    && pip install pytz \
    && pip install pyOpenSSL \
    && pip install ndg-httpsclient \
    && pip install pyasn1 \
    && pip install docker \
    && pip install bcrypt \
    && pip install flask-bcrypt \
    && pip install pymssql \
    && pip install pyodbc \
    && pip install numpy \
    && pip install scipy \
    && pip install pandas \
    && pip install sympy \
    && pip install client \
    && pip install suds==0.4 \
    && pip install suds-jurko==0.6 \
    && pip install apache-airflow[crypto,celery,postgres,hive,jdbc,mysql,ssh${AIRFLOW_DEPS:+,}${AIRFLOW_DEPS}]==${AIRFLOW_VERSION} \
    && pip install 'redis>=3.2.0' \
    && if [ -n "${PYTHON_DEPS}" ]; then pip install ${PYTHON_DEPS}; fi \
    ## Clean up from R source install
    && cd / \
    && rm -rf /tmp/* \
    && apt-get purge --auto-remove -yqq $buildDeps \
    && apt-get autoremove -yqq --purge \
    && apt-get clean \
    && rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /usr/share/man \
        /usr/share/doc \
        /usr/share/doc-base

ENV PATH="/opt/mssql-tools/bin:${PATH}"

RUN Rscript -e "if (!require(devtools)) install.packages('devtools')" \
    && Rscript -e "devtools::source_url('https://raw.githubusercontent.com/shizidushu/common-pkg-list/master/r-pkgs.R')" \
    && rm -rf /tmp/Rtmp*

COPY script/entrypoint.sh /entrypoint.sh
COPY config/airflow.cfg ${AIRFLOW_HOME}/airflow.cfg

RUN chown -R airflow: ${AIRFLOW_HOME}

EXPOSE 8080 5555 8793

USER airflow
WORKDIR ${AIRFLOW_HOME}
ENTRYPOINT ["/entrypoint.sh"]
CMD ["webserver"] # set default arg for entrypoint
