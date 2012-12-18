################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/common.c \
../src/connection_server.c \
../src/dispatch.c \
../src/init.c \
../src/low_level_op.c \
../src/main.c \
../src/platform.c \
../src/server.c 

LD_SRCS += \
../src/lscript.ld 

OBJS += \
./src/common.o \
./src/connection_server.o \
./src/dispatch.o \
./src/init.o \
./src/low_level_op.o \
./src/main.o \
./src/platform.o \
./src/server.o 

C_DEPS += \
./src/common.d \
./src/connection_server.d \
./src/dispatch.d \
./src/init.d \
./src/low_level_op.d \
./src/main.d \
./src/platform.d \
./src/server.d 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.c
	@echo Building file: $<
	@echo Invoking: MicroBlaze gcc compiler
	mb-gcc -Wall -O0 -g3 -c -fmessage-length=0 -D __XMK__ -I../../fmc150_acquisition_lwip_bsp_0/microblaze_0/include -mlittle-endian -mxl-barrel-shift -mxl-pattern-compare -mcpu=v8.20.b -mno-xl-soft-mul -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@:%.o=%.d)" -o"$@" "$<"
	@echo Finished building: $<
	@echo ' '


