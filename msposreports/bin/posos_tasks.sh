#!/bin/bash

find ../../msposapp/bin/* -exec grep "^# " {} \; | grep -v Binary | grep -v directory | grep -v bash
