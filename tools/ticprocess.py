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
MQTT_BROKER = "hap-ac2"		# adresse du broker MQTT
MQTT_TOPIC = "sensors/switch/delest"	# topic MQTT
MQTT_SKIP = 8			# nombre de trames à ignorer entre chaque publication MQTT
ETIQ_POWER = "SINSTS"		# en mono: TICv1: "PAPP", TICv2: "SINSTS"
ETIQ_MSG = "MSG1"		# MSG1: message court (32c), MSG2: message ultra court (16c)
VA_THRESH = 9000		# valeur limite de la puissance apparente (en VA)


lastmsg = ""
filtva = 0

def print_msg(tic):
	global lastmsg

	m = tic.get(ETIQ_MSG)
	if m:
		m = m.get("data")
		if m != lastmsg:
			lastmsg = m
			print(m)	# print new messages to stdout
			sys.stdout.flush()

def over_vatresh(tic):
	global filtva
	state = None

	s = tic.get(ETIQ_POWER)
	if s:
		va = s.get("data")
		if va > max(filtva, VA_THRESH):
			filtva = va	# overflow overrides value
		else:
			filtva = filtva - 1/60*(filtva - va)    # average 60 samples, ~1mn - provides hysteresis on down slope
		state = (filtva > VA_THRESH)

	return state


sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
skip = 0


for ticjsonline in sys.stdin:
	sock.sendto(bytes(ticjsonline, "utf-8"), (UDP_IP, UDP_PORT))
	try:
		tic = json.loads(ticjsonline)
		v = tic.get("_tvalide")
		if v:
			print_msg(tic)
			delest = over_vatresh(tic)
			if not skip:
				publish.single(MQTT_TOPIC, delest, hostname=MQTT_BROKER)
				skip = MQTT_SKIP
			skip -= 1
	except:
		pass
