#!/bin/bash

time docker build . -t librecat/catmandu
docker run -v /Users/admin/git/msw/polaris-os/polaris-os-oai/Catmandu/conf:/home/catmandu -it librecat/catmandu

# catmandu import OAI --url https://lib.ugent.be/oai --metadataPrefix oai_dc --set flandrica --handler oai_dc to Elasticsearch --index_name oai --bag publication
