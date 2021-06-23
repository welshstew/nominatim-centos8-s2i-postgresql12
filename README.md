# nominatim-centos8-s2i-postgresql12

An awful attempt to get a postgis postgresql12 image together for a Nominatim application to connect into.

```
podman build -t quay.io/swinches/nominatim-postgresql:latest .
podman push quay.io/swinches/nominatim-postgresql:latest
```