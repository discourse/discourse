#!/bin/bash
su - postgres
psql discourse < /tmp/images/production-image.sql
exit