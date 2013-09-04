#!/bin/bash
su - postgres
psql -d discourse < production-image.sql
exit