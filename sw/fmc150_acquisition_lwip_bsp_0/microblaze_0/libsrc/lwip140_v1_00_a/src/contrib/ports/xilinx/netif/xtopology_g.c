#include "netif/xtopology.h"

struct xtopology_t xtopology[] = {
	{
		0x41240000,
		xemac_type_axi_ethernet,
		0x41200000,
		-1,
		0x0,
		0x0,
	},
};

int xtopology_n_emacs = 1;
