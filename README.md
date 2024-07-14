# An In-depth Study of Runtime Verification Overheads during Software Testing

## Appendix
See [appendix.pdf](appendix.pdf)

## Projects and data
You can find our 1544 projects [here](data/projects-usable.csv). The first column is the projects name, second column is its SHA, and third column is its URL.
You can find all the projects' data in this [directory](data).

## Repository structure
| Directory               | Purpose                                    |
| ------------------------| ------------------------------------------ |
| Docker                  | scripts to run our experiments in Docker   |
| compile-time-weaving    | infrastructure for offline instrumentation |
| data                    | raw data (see section above)               |
| experiments             | scripts to run our experiments             |
| javamop-maven-extension | a collection of Maven extensions           |
| mop                     | a collection of JavaMOP specifications     |
| profiling               | scripts to run projects with profiler      |
| scripts                 | our JavaMOP extension                      |

## Usage
### Prerequisites:
- A x86-64 architecture machine
- Ubuntu 20.04
- [Docker](https://docs.docker.com/get-docker/)
### Setup
First, you need to build a Docker image. Run the following commands in terminal.
```sh
docker build -f Docker/Dockerfile . --tag=rvpaper:latest
docker run -it --rm rvpaper:latest
./setup.sh  # run this command in Docker container
```
Then, run the following command in a new terminal window.
```sh
docker ps  # get container id
docker commit <container-id> rvpaper:latest
```

### Run pipeline
```sh
cd Docker

# Run 1 of the below
# 1) if you want to run pipeline on all projects (could take multiple days)
cp projects.csv projects-pipeline.csv
# 2) if you want to run pipeline on a small subset of projects (should take less than 1 hour)
cp projects-subset.csv projects-pipeline.csv

bash experiments_in_docker.sh -p projects-pipeline.csv -o pipeline-output -c 3600s -a 10800s -v ajc
# You can ignore "Error response from daemon" messages, and check pipeline-output for output
```
This pipeline includes:
- measure test time
- measure MOP time
- run MOP with profiler
- pre-instrument project for offline instrumentation
- run MOP with pre-instrumented code

### Collect traces for all projects
```sh
cd Docker

# Run 1 of the below
# 1) if you want to collect traces all projects (could take multiple days)
cp projects.csv projects-traces.csv
# 2) if you want to collect traces for a small subset of projects (should take less than 30 minutes)
cp projects-subset.csv projects-traces.csv

bash collect_traces_in_docker.sh -p projects-traces.csv -o traces-output
# Check traces-output for output
```

### incremental offline instrumentation vs evolution-aware RV
```sh
cd Docker/evolution

# Run 1 of the below
# 1) if you want to compare all 35 projects (could take multiple days)
cp projects.txt projects-evolution.txt
# 2) if you want to compare a small subset of projects (should take less than 1 day)
cp projects-subset.txt projects-evolution.txt

bash get_emop_time_in_docker.sh $(pwd)/projects-evolution.txt $(pwd)/sha $(pwd)/evolution-output
# Check evolution-output/get_emop_time for output

# Run 1 of the below
# 1) if you want to compare all 35 projects (could take multiple days)
cp projects.txt projects-evolution.txt
# 2) if you want to compare a small subset of projects (should take less than 1 day)
cp projects-subset.txt projects-evolution.txt

bash get_ctw_time_in_docker.sh $(pwd)/projects-evolution.txt $(pwd)/sha $(pwd)/evolution-output
# Check evolution-output/get_ctw_time for output
```
