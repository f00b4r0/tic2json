COMPONENT_SRCDIRS := src
CFLAGS += -DBAREBUILD

ifdef CONFIG_TIC2JSON_TICV01
CFLAGS += -DTICV01
endif

ifdef CONFIG_TIC2JSON_TICV02
CFLAGS += -DTICV02
endif

$(COMPONENT_LIBRARY):	csource

csource:
	make -C $(COMPONENT_PATH)/$(COMPONENT_SRCDIRS) csources

.PHONY: csource