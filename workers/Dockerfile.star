FROM miserlou/star_base

COPY common/dist/data-refinery-common-* common/

COPY workers/requirements.txt .
# The base image does not have Python 2.X on it at all, so all calls
# to pip or python are by default calls to pip3 or python3
RUN pip install -r requirements.txt

# Get the latest version from the dist directory.
RUN pip3 install common/$(ls common -1 | sort --version-sort | tail -1)

COPY workers/ .

ENTRYPOINT ["python3", "manage.py"]
