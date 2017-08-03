#
# Makefile
# Pi-Yueh Chuang, 2017-07-06 12:39
#


# set up environment
CXX = CC
CXXFLAGS = -std=c++11 -w \
		   -acc -ta=host,tesla:cc35 -Minfo=accel \
		   -I./extra/petsc-3.7.6/include \
		   -I./extra/petsc-3.7.6/RELEASE-TITAN/include
LDFLAGS = -acc -ta=host,tesla:cc35 -Minfo=accel

# directories
SRCDIR = ./src
OBJDIR = ./obj
BINDIR = ./bin
LIBDIR = ./lib

# Score-P flags
SCOREP_FLAGS = --static --mpp=mpi --openacc --cuda

# PGprof flags
PGPROF_FLAGS = -Mprof=ccff

# source files
SRC = helper.cpp main_ksp.cpp
KERNEL = MatAssemblyEnd_SeqAIJ.c MatDestroy_SeqAIJ.c MatMult_SeqAIJ.c

# PETSc
PETSCLIB = extra/petsc-3.7.6/RELEASE-TITAN/lib/libpetsc.a

# executable binary files
EXE = petsc-ksp-original petsc-ksp-scorep-original petsc-ksp-pgprof-original \
	  petsc-ksp-openacc petsc-ksp-scorep-openacc petsc-ksp-pgprof-openacc

# PBS job targets
RUNS := $(subst .pbs, , $(subst runs/, run-, $(wildcard runs/*.pbs)))

# phony targets
.PHONY: help list-executables list-runs all build-petsc \
	clean-build clean-petsc clean-all check-dir ${EXE} ${RUNS}

# preserve object files
.PRECIOUS: ${OBJDIR}/%.o ${OBJDIR}/%.pgprof.o ${OBJDIR}/%.scorep.o

# remove all suffix implicit rules
.SUFFIXES:

# help
help:
	@printf "\n"
	@printf "Usage:\n"
	@printf "\n"
	@printf "\tmake build-petsc\n"
	@printf "\tmake [make options] all\n"
	@printf "\tmake [make options] INDIVIDUAL_EXECUTABLE_NAME\n"
	@printf "\tmake [make options] PROJ=<chargeable project> PBS_RUN\n"
	@printf "\n"
	@printf "List all targets:\n"
	@printf "\n"
	@printf "\tmake list\n"
	@printf "\n"
	@printf "List targets of executable:\n"
	@printf "\n"
	@printf "\tmake list-executables\n"
	@printf "\n"
	@printf "List targets of PBS runs:\n"
	@printf "\n"
	@printf "\tmake list-runs\n"
	@printf "\n"

space :=
space +=
# list all targets
list: list-executables list-runs
	@printf "\n"
	@printf "Other targets:\n\n"
	@printf "\tall\n"
	@printf "\tbuild-petsc\n"
	@printf "\tclean-build\n"
	@printf "\tclean-petsc\n"
	@printf "\tclean-all\n"
	@printf "\n"

# list all targets of executables
list-executables:
	@printf "\n"
	@printf "Available exectuables:\n\n"
	@printf "\t$(subst ${space},\n\t,$(strip ${EXE}))\n"
	@printf "\n"

# list all targets of executables
list-runs:
	@printf "\n"
	@printf "Available PBS runs:\n\n"
	@printf "\t$(subst ${space},\n\t,$(strip ${RUNS}))\n"
	@printf "\n"

# target all
all: ${EXE}

# build PETSc library
build-petsc: ${PETSCLIB}

# makeing an executable
${EXE}: %: ${PETSCLIB} check-dir ${BINDIR}/%

# real target that creates petsc-ksp-scorep-*
${BINDIR}/petsc-ksp-scorep-%: \
	$(foreach i, $(SRC:.cpp=.scorep.o), ${OBJDIR}/${i})\
	$(foreach i, $(KERNEL:.c=.scorep.o), ${OBJDIR}/%/${i})

	scorep ${SCOREP_FLAGS} ${CXX} -o $@ $^ ${LDFLAGS} ${PETSCLIB}

# real target that creates petsc-ksp-pgprof-*
${BINDIR}/petsc-ksp-pgprof-%: \
	$(foreach i, $(SRC:.cpp=.pgprof.o), ${OBJDIR}/${i})\
	$(foreach i, $(KERNEL:.c=.pgprof.o), ${OBJDIR}/%/${i})

	${CXX} ${PGPROF_FLAGS} -o $@ $^ ${LDFLAGS} ${PETSCLIB}

# real target that creates petsc-ksp-*
${BINDIR}/petsc-ksp-%: \
	$(foreach i, $(SRC:.cpp=.o), ${OBJDIR}/${i})\
	$(foreach i, $(KERNEL:.c=.o), ${OBJDIR}/%/${i})

	${CXX} -o $@ $^ ${LDFLAGS} ${PETSCLIB}

# underlying target to build PETSc
${PETSCLIB}: \
	$(wildcard extra/petsc-3.7.6/src/**/*.c) \
	$(wildcard extra/petsc-3.7.6/src/**/*.h)

	sh -l scripts/petsc.sh

# underlying rule compiling C++ code with Score-P
${OBJDIR}/%.scorep.o: ${SRCDIR}/%.cpp
	scorep ${SCOREP_FLAGS} ${CXX} -c -o $@ $< ${CXXFLAGS}

# underlying rule compiling C code with Score-P
${OBJDIR}/%.scorep.o: ${SRCDIR}/%.c
	scorep ${SCOREP_FLAGS} ${CXX} -c -o $@ $< ${CXXFLAGS}

# underlying rule compiling C++ code with PGprof
${OBJDIR}/%.pgprof.o: ${SRCDIR}/%.cpp
	${CXX} ${PGPROF_FLAGS} -c -o $@ $< ${CXXFLAGS}

# underlying rule compiling C code with PGprof
${OBJDIR}/%.pgprof.o: ${SRCDIR}/%.c
	${CXX} ${PGPROF_FLAGS} -c -o $@ $< ${CXXFLAGS}

# underlying target compiling C++ code
${OBJDIR}/%.o: ${SRCDIR}/%.cpp
	${CXX} -c -o $@ $< ${CXXFLAGS}

# underlying target compiling C code
${OBJDIR}/%.o: ${SRCDIR}/%.c
	${CXX} -c -o $@ $< ${CXXFLAGS}

# rule to run PBS script in directory "runs"
${RUNS}:
	qsub -v PROJ=${PROJ} $(subst run-, runs/, $@).pbs

# check and create necessary directories
check-dir:
	@if [ ! -d ${OBJDIR} ]; then mkdir ${OBJDIR}; fi
	@if [ ! -d ${OBJDIR}/original ]; then mkdir ${OBJDIR}/original; fi
	@if [ ! -d ${OBJDIR}/openacc ]; then mkdir ${OBJDIR}/openacc; fi
	@if [ ! -d ${BINDIR} ]; then mkdir ${BINDIR}; fi

# clean executables and object files
clean-build:
	@rm -rf ${OBJDIR} ${BINDIR}

# clean everything from PETSc
clean-petsc:
	@rm -rf extra

# clean everything
clean-all: clean-build clean-petsc

# vim:ft=make
