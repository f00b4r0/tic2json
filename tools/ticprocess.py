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
MQTT_TOPIC_DELEST = "sensors/switch/delest"	# topic MQTT delestage, True if load > VA_THRESH or HP Rouge
MQTT_TOPIC_ALLOWDHW = "sensors/switch/dhwt"	# topic MQTT ECS OK, 1 if "RELAIS" == 1
MQTT_TOPIC_DAYCOLOR = "tic/color"	# -, B, W, R
MQTT_TOPIC_NDAYCOLOR = "tic/ncolor"	# -, B, W, R
MQTT_TOPIC_DAYHC = "tic/hc"	# 1 if HC, 0 otherwise (HP)
MQTT_TOPIC_POWER = "tic/power"
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

# seulement pour TIC v02
def inhibit_loads(tic):
	t = tic.get("NTARF")
	t = t and t.get("data")

	# force delest when NTARF=6 (HP Rouge)
	return t and (t == 6)

def allow_edhw(tic):
	r = tic.get("RELAIS")
	r = r and r.get("data")

	# allow if "real" (id 1) relay is active
	return r and (r & 0x1)

def day_hc(tic):
	t = tic.get("NTARF")
	t = t and t.get("data")

	# HC: NTARF odd, HP: NTARF even
	return t and (t % 2)

def tempo_colors(tic):
	s = tic.get("STGE")
	s = s and s.get("data")

	if not s:
		return ("-","-")

	d = s>>24 & 0x3
	nd = s>>26 & 0x3
	tempo = ("-","B","W","R")

	return (tempo[d], tempo[nd])


sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
skip = 0


for ticjsonline in sys.stdin:
	sock.sendto(bytes(ticjsonline, "utf-8"), (UDP_IP, UDP_PORT))
	try:
		tic = json.loads(ticjsonline)
		v = tic.get("_tvalide")
		if v:
			print_msg(tic)

			delest = inhibit_loads(tic) or over_vatresh(tic)
			edhwok = allow_edhw(tic)
			dayhc = day_hc(tic)
			colors = tempo_colors(tic)
			p = tic.get(ETIQ_POWER)
			p = p and p.get("data")

			mqttmsgs = [
				( MQTT_TOPIC_DELEST, delest, 0, False),
				( MQTT_TOPIC_ALLOWDHW, edhwok, 0, False),
				( MQTT_TOPIC_DAYHC, dayhc, 0, False),
				( MQTT_TOPIC_DAYCOLOR, colors[0], 0, False),
				( MQTT_TOPIC_NDAYCOLOR, colors[1], 0, False),
				( MQTT_TOPIC_POWER, p, 0, False),
			]

			if not skip:
				publish.multiple(mqttmsgs, hostname=MQTT_BROKER)
				skip = MQTT_SKIP
			skip -= 1
	except:
		pass
