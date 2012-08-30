#! /bin/bash
rake generate
rsync -avz public/* fenbi@211.151.121.133:/global/online/blog/
