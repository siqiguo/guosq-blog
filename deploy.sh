#! /bin/bash
rake generate
scp -r public/* fenbi@211.151.121.133:/global/online/blog/
