# BoursoExtractor
Extrait les informations bancaires de votre compte Boursorama dans une table MySQL

# Installation

Requiert: mysql, perl, sed, grep, awk...

Testé sous Debian 8

## Création de la base MySQL

    mysql -e "create database bourso"
    mysql bourso <schema.sql

## Téléchargement des relevés bancaires

Télécharger tous les relevés de compte courant et de carte bleue sur le site de boursorama. Utiliser un mass-downloader tel que uSelect iDownload, pour télécharger l'ensemble des PDF d'un coup.

Les placer dans le répertoire `input` (à créer)

## Conversion

Exécuter le script:

    ./parse.sh

# Résultat

La table est remplie de vos opérations bancaires.

Voici un exemple (semi censuré) de 5 opérations :

    *************************** 1. row ***************************
            id: 1029
           op_date: 2014-07-21
           op_type: PAIEMENT CARTE
       op_location: 35
    op_description: REL.RENNES LECL
    op_date_valeur: 2014-07-20
          op_value: -60.710
    *************************** 2. row ***************************
            id: 1567
           op_date: 2014-07-21
           op_type: PRLV
       op_location: 
    op_description: SEPA FREE MOBILE
    op_date_valeur: 2014-07-21
          op_value: -15.990
    *************************** 3. row ***************************
            id: 1568
           op_date: 2014-07-21
           op_type: VIR
       op_location: 
    op_description: PriceMinister
    op_date_valeur: 2014-07-21
          op_value: -397.000
    *************************** 4. row ***************************
            id: 1569
           op_date: 2014-07-21
           op_type: REM CHQ
       op_location: 
    op_description: N. 268XXXX
    op_date_valeur: 2014-07-21
          op_value: 400.000
    *************************** 5. row ***************************
            id: 1030
           op_date: 2014-07-24
           op_type: PAIEMENT CARTE
       op_location: 35
    op_description: 5 A SEC
    op_date_valeur: 2014-07-23
          op_value: -12.950

A vous de créer des graphes, statistiques...

