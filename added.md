

    && groupadd --gid 119 docker \
    && useradd --shell /bin/bash \
        --create-home \
        --home-dir ${AIRFLOW_HOME} \
        airflow \
    && usermod -aG docker airflow \
    
    
    && pip install docker \
    && pip install bcrypt \
    && pip install flask-bcrypt \