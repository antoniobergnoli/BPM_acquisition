/* This code was extracted from:
 * http://beej.us/guide/bgnet/output/html/singlepage/bgnet.html#serialization
 * under NO license
 */

#ifndef PACK_H_
#define PACK_H_

/* Prototypes for helper functions*/
unsigned long long int pack754(long double f, unsigned bits, unsigned expbits);
long double unpack754(unsigned long long int i, unsigned bits, unsigned expbits);
void packi16(unsigned char *buf, unsigned short int i);
void packi32(unsigned char *buf, unsigned int i);
void packi64(unsigned char *buf, unsigned long long int i);
short unpacki16(unsigned char *buf);
unsigned short unpacku16(unsigned char *buf);
int unpacki32(unsigned char *buf);
unsigned int unpacku32(unsigned char *buf);
long long int unpacki64(unsigned char *buf);
unsigned long long int unpacku64(unsigned char *buf);

/* API for pck and unpack */
unsigned int pack(unsigned char *buf, char *format, ...);
void unpack(unsigned char *buf, char *format, ...);


#endif /* PACK_H_ */
