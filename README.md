Thread -- Quick Start
---------------------

### Install mongodb ###

http://docs.mongodb.org/manual/tutorial/install-mongodb-on-os-x/

    brew update
    brew install mongodb
    mkdir -p /data/db
    # chmod if needed
    mongod # start mongo server

### Run tests ###

    rspec

### Start server ###

    shotgun # auto-reloads on each request (for dev)

Surf to: http://localhost:9393
