PROJECT_NAME='ashraf-magic'

# Check if the network exists; if not, create it
if ! docker network inspect ${PROJECT_NAME}-network &>/dev/null; then
    docker network create ${PROJECT_NAME}-network
else
    echo "Network ${PROJECT_NAME}-network already exists."
fi

# Start Kafka Containers
start-kafka(){
    docker-compose -f docker/kafka/docker-compose.yml up -d
}


# Start Mage Containers
start-mage(){
    docker build -t mage_spark docker/mage
    docker-compose -f docker/mage/docker-compose.yml up -d

    sudo cp batch_pipeline/export_to_bigquery/data_exporters/* docker/mage/${PROJECT_NAME}/data_exporters/
    sudo cp batch_pipeline/export_to_bigquery/data_loaders/* docker/mage/${PROJECT_NAME}/data_loaders/

    sudo mkdir docker/mage/${PROJECT_NAME}/pipelines/batch_pipeline
    sudo touch docker/mage/${PROJECT_NAME}/pipelines/batch_pipeline/__init__.py
    sudo cp batch_pipeline/export_to_bigquery/*.yaml docker/mage/${PROJECT_NAME}/pipelines/batch_pipeline/

    sudo cp streaming_pipeline/kafka_to_gcs_streaming/consumer_from_kafka.yaml docker/mage/${PROJECT_NAME}/data_loaders/
    sudo cp streaming_pipeline/kafka_to_gcs_streaming/kafka_to_gcs docker/mage/${PROJECT_NAME}/data_exporters/

    sudo mkdir docker/mage/${PROJECT_NAME}/pipelines/streaming_pipeline
    sudo touch docker/mage/${PROJECT_NAME}/pipelines/streaming_pipeline/__init__.py
    sudo cp streaming_pipeline/kafka_to_gcs_streaming/metadata.yaml docker/mage/${PROJECT_NAME}/pipelines/streaming_pipeline/
    
    
    
}

#Start producing stream data
stream-data(){
    docker-compose -f docker/streaming/docker-compose.yml up 
}


start-spark(){
    chmod +x ./docker/spark/build.sh
    ./docker/spark/build.sh

    docker-compose -f docker/spark/docker-compose.yml up -d
}

#Git stage,commit and push
gitting(){
    git add .
    git commit -m "Update from local"
    sleep 2
    git push -u origin main
}


#Terraform actions
terraform-start(){
    terraform -chdir=terraform init
    terraform -chdir=terraform plan
    terraform -chdir=terraform apply
}

terraform-destroy(){
    terraform -chdir=terraform destroy
}
gcs-to-bigquery-pipeline(){
    curl -X POST https://zany-space-xylophone-5g5p74jwr9j37664-6789.app.github.dev/api/pipeline_schedules/1/pipeline_runs/0dac6dcd9ada49f1a1ba6866424aaebe \
    --header 'Content-Type: application/json' \
    --data '
    {
    "pipeline_run": {
        "variables": {
        "key1": "value1",
        "key2": "value2"
        }
    }
    }'
}

olap-transformation-pipeline(){
    python batch_pipeline/export_to_gcs/pipeline.py
}