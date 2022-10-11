#!/usr/bin/python3

##
##  ticprocess.py
##  Basic processing of tic2json dictionary output
##
##  (C) 2022 Thibaut VARENE
##  License: GPLv2 - http://www.gnu.org/licenses/gpl-2.0.html
##

# Lit la sortie dictionnaire de tic2json, et:
# - envoie la trame JSON brute via UDP,
# - vérifie la puissance apparente soutirée actuelle et publie via MQTT un statut de délestage suivant que la valeur VA_THRESH est dépassée ou non
# - émets les messages courants sur la sortie standard
# Permet par exemple de piloter une demande de délestage via MQTT tout en enregistrant les données avec telegraf
# Exemple d'utilisation: stdbuf -oL tic2json -d | ticprocess.py

import sys
import socket
import json
import paho.mqtt.publish as publish


# Configuration variables
UDP_IP = "grafana"		# adresse où envoyer le paquet UDP
UDP_PORT = 8094			# port UDP
MQTT_BROKER = "hap-acl"		# adresse du broker MQTT
MQTT_TOPIC = "energy/delest"	# topic MQTT
MQTT_SKIP = 10			# nombre de trames à ignorer entre chaque publication MQTT
ETIQ_POWER = "SINSTS"		# en mono: TICv1: "PAPP", TICv2: "SINSTS"
ETIQ_MSG = "MSG1"		# MSG1: message court (32c), MSG2: message ultra court (16c)
VA_THRESH = 8900		# valeur limite de la puissance apparente (en VA)


lastmsg = ""

def over_vatresh(ticjsonline):
	global lastmsg
	state = None
	try:
		tic = json.loads(ticjsonline)
		s = tic.get(ETIQ_POWER)
		v = tic.get("_tvalide")

		m = tic.get(ETIQ_MSG)		# grab message while we're there
		if v and m:
			m = m.get("data")
			if m != lastmsg:
				lastmsg = m
				print(m)	# print new messages to stdout
				sys.stdout.flush()

		if v and s:
			if s.get("data") > VA_THRESH:
				state = True
			else:
				state = False
	except:
		pass
	return state

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
skip = 0

for ticjsonline in sys.stdin:
	sock.sendto(bytes(ticjsonline, "utf-8"), (UDP_IP, UDP_PORT))
	delest = over_vatresh(ticjsonline)
	if not skip:
		publish.single(MQTT_TOPIC, delest, hostname=MQTT_BROKER)
		skip = MQTT_SKIP
	skip -= 1
