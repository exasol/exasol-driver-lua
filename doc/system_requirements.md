<head><link href="oft_spec.css" rel="stylesheet"></head>

# System Requirement Specification &mdash; Exasol Driver for Lua

## Introduction

The Exasol eriver for Lua (EDL) is a library for Lua that allows accessing an Exasol database to insert, update, delete and query data. EDL provides an API interface that closely resembles the API of [LuaSQL](https://keplerproject.github.io/luasql/) in order to be a drop-in replacement.

## About This Document

### Target Audience

The target audience are end-users, requirement engineers, software designers and quality assurance. See section ["Stakeholders"](#stakeholders) for more details.

### Goal

The EDL main goal is to provide a ready-to-use library for accessing an Exasol database in Lua.

## Stakeholders

### Software Developers

Software Developers use this library as basis for writing Lua applications that access an Exasol database.

### Terms and Abbreviations

The following list gives you an overview of terms and abbreviations commonly used in OFT documents.

* ...

## Features

Features are the highest level requirements in this document that describe the main functionality of EDL.

### LuaSQL API Interface
`feat~luasql-api~1`

EDL implements the [LuaSQL](https://keplerproject.github.io/luasql/) API as closely as possible.

Rationale:

LuaSQL is a mature library used in many projects. Lua developers are already familiar with its API. Implementing the LuaSQL API avoids reinventing the wheel and potential mistakes when designing a new API from scratch.

Extending the API with Exasol specific extensions is however possible and already done for other databases.

Needs: req

## Functional Requirements

### Connect With Username and Password
`req~connect-with-username-password~1`

EDL can connect to an Exasol database and authenticate with username and password as credentials.

Covers:

* [feat~luasql-api~1](#luasql-api-interface)

Needs: dsn

### 