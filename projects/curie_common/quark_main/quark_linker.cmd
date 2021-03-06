/*
 * Copyright (c) 2013-2014 Wind River Systems, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @file
 * @brief Common linker sections
 *
 * This script defines the memory location of the various sections that make up
 * a Zephyr Kernel image. This file is used by the linker.
 *
 * This script places the various sections of the image according to what
 * features are enabled by the kernel's configuration options.
 *
 * For a build that does not use the execute in place (XIP) feature, the script
 * generates an image suitable for loading into and executing from RAM by
 * placing all the sections adjacent to each other.  There is also no separate
 * load address for the DATA section which means it doesn't have to be copied
 * into RAM.
 *
 * For builds using XIP, there is a different load memory address (LMA) and
 * virtual memory address (VMA) for the DATA section.  In this case the DATA
 * section is copied into RAM at runtime.
 *
 * When building an XIP image the data section is placed into ROM.  In this
 * case, the LMA is set to __data_rom_start so the data section is concatenated
 * at the end of the RODATA section.  At runtime, the DATA section is copied
 * into the RAM region so it can be accessed with read and write permission.
 *
 * Most symbols defined in the sections below are subject to be referenced in
 * the Zephyr Kernel image. If a symbol is used but not defined the linker will
 * emit an undefined symbol error.
 *
 * Please do not change the order of the section as the nanokernel expects this
 * order when programming the MMU.
 */

#define _LINKER
#define _ASMLANGUAGE /* Needed to include mmustructs.h */

#include <autoconf.h>
#include <linker-defs.h>
#include <offsets.h>
#include <misc/util.h>

#define MMU_PAGE_SIZE KB(4)

#include <linker-tool.h>

#include <mem_map.h>

/* physical address where the kernel is loaded */
#define PHYS_LOAD_ADDR FLASH_START

/* physical address of RAM (needed for correct __ram_phys_end symbol) */
#ifdef CONFIG_XIP
  #define PHYS_RAM_ADDR    RAM_START
#else  /* !CONFIG_XIP */
  #define PHYS_RAM_ADDR    PHYS_LOAD_ADDR
#endif /* CONFIG_XIP */

#define KENTRY __start

MEMORY
    {
#ifdef CONFIG_XIP
    ROM (rx)        : ORIGIN = PHYS_LOAD_ADDR, LENGTH = FLASH_SIZE
    RAM (wx)        : ORIGIN = PHYS_RAM_ADDR, LENGTH = RAM_SIZE*1K
    DCCM  (wx)      : ORIGIN = DCCM_START,  LENGTH = DCCM_SIZE
#else  /* !CONFIG_XIP */
    RAM (wx)        : ORIGIN = PHYS_LOAD_ADDR, LENGTH = RAM_SIZE*1K
#endif /* CONFIG_XIP */

    /*
     * It doesn't matter where this region goes as it is stripped from the
     * final ELF image. The address doesn't even have to be valid on the
     * target. However, it shouldn't overlap any other regions.
     */

    IDT_LIST        : ORIGIN = 2K, LENGTH = 2K
    }



/* SECTIONS definitions */
SECTIONS
	{
	GROUP_START(ROMABLE_REGION)

	_image_rom_start = PHYS_LOAD_ADDR;
	_image_text_start = PHYS_LOAD_ADDR;

	SECTION_PROLOGUE (version_header_section, (OPTIONAL),)
	{
		. += CONFIG_SIGNATURE_HEADER_SIZE;
		*(.version_header)
		KEEP(*(".version_header*"))
	} GROUP_LINK_IN(ROMABLE_REGION)

	SECTION_PROLOGUE(_TEXT_SECTION_NAME, (OPTIONAL),)
	{

	*(.text_start)
	*(".text_start.*")
	*(.text)
	*(".text.*")
	*(.eh_frame)
	*(.init)
	*(.fini)
	*(.eini)
	KEXEC_PGALIGN_PAD(MMU_PAGE_SIZE)
	} GROUP_LINK_IN(ROMABLE_REGION)

	_image_text_end = .;

        GROUP_START(DCCM)
            SECTION_PROLOGUE(dccm,(NOLOAD),)
            {
                    . = ALIGN(4);
                    __dccm_start = .;
                    *(.dccm)
                        _dccm_end = ALIGN(4);
            } GROUP_LINK_IN(DCCM)
        GROUP_END(DCCM)

        SECTION_PROLOGUE (.dccm, (OPTIONAL),)
        {
        . = ALIGN(4);
        __dccm_start = .;
        *(.dccm)
        _dccm_end = ALIGN(4);
        } GROUP_LINK_IN(ROMABLE_REGION)

	SECTION_PROLOGUE (.openinit, (OPTIONAL),) {
/* This section is used to store open sensor_core funcs,data*/
        . = ALIGN(8);
        _s_openinit = .;

        _s_feedinit = .;
        KEEP (*(.openinit.feed))
        _e_feedinit = .;

        _s_exposedinit = .;
        KEEP(*(.openinit.exposed))
        _e_exposedinit = .;

        KEEP (*(.openinit.data))
        KEEP (*(.openinit))
        _e_openinit = .;
        } GROUP_LINK_IN(ROMABLE_REGION)


	SECTION_PROLOGUE(devconfig, (OPTIONAL),)
	{
		__devconfig_start = .;
		*(".devconfig.*")
		KEEP(*(SORT_BY_NAME(".devconfig*")))
		__devconfig_end = .;
	} GROUP_LINK_IN(ROMABLE_REGION)

        SECTION_PROLOGUE (tcmd_section, (OPTIONAL),)
        {
                 /* This section is used to store test commands.  */
                . = ALIGN(8);
                __test_cmds_start = .;
                KEEP(*(SORT(.test_cmds.*)))
                __test_cmds_end = .;
        } GROUP_LINK_IN(ROMABLE_REGION)

	SECTION_PROLOGUE(cfw_services_section, (OPTIONAL),)
	{
		/* This section is used to store registered CFW services  */
		. = ALIGN(8);
		__cfw_services_start = .;
		KEEP(*(SORT(.cfw_services.*)))
		__cfw_services_end = .;
	} GROUP_LINK_IN(ROMABLE_REGION)

	SECTION_PROLOGUE(_RODATA_SECTION_NAME, (OPTIONAL),)
	{
	*(.rodata)
	*(".rodata.*")
	IRQ_TO_INTERRUPT_VECTOR_MEMORY
	KEXEC_PGALIGN_PAD(MMU_PAGE_SIZE)
	} GROUP_LINK_IN(ROMABLE_REGION)

	_image_rom_end = .;
	__data_rom_start = ALIGN(4);		/* XIP imaged DATA ROM start addr */

	GROUP_END(ROMABLE_REGION)

	/* RAM */
	GROUP_START(RAM)

#if defined(CONFIG_XIP)
	SECTION_AT_PROLOGUE(_DATA_SECTION_NAME, (OPTIONAL), , __data_rom_start)
#else
	SECTION_PROLOGUE(_DATA_SECTION_NAME, (OPTIONAL),)
#endif
	{
	KEXEC_PGALIGN_PAD(MMU_PAGE_SIZE)
	_image_ram_start = .;
	__data_ram_start = .;
	*(.data)
	*(".data.*")
	IDT_MEMORY
	INTERRUPT_VECTORS_ALLOCATED_MEMORY
	. = ALIGN(4);
	} GROUP_LINK_IN(RAM)

	SECTION_PROLOGUE(initlevel, (OPTIONAL),)
	{
		DEVICE_INIT_SECTIONS()
		KEXEC_PGALIGN_PAD(MMU_PAGE_SIZE)
	} GROUP_LINK_IN(RAM)

	SECTION_PROLOGUE(_k_task_list, ALIGN(4), ALIGN(4))
	{
		_k_task_list_start = .;
			*(._k_task_list.public.*)
			*(._k_task_list.private.*)
		_k_task_list_idle_start = .;
			*(._k_task_list.idle.*)
		KEEP(*(SORT_BY_NAME("._k_task_list*")))
		_k_task_list_end = .;
	} GROUP_LINK_IN(RAM)

	SECTION_PROLOGUE(_k_task_ptr, (OPTIONAL),)
	{
		_k_task_ptr_start = .;
			*(._k_task_ptr.public.*)
			*(._k_task_ptr.private.*)
			*(._k_task_ptr.idle.*)
		KEEP(*(SORT_BY_NAME("._k_task_ptr*")))
		_k_task_ptr_end = .;
	} GROUP_LINK_IN(RAM)

	SECTION_PROLOGUE(_k_pipe_ptr, (OPTIONAL),)
	{
		_k_pipe_ptr_start = .;
			*(._k_pipe_ptr.public.*)
			*(._k_pipe_ptr.private.*)
		KEEP(*(SORT_BY_NAME("._k_pipe_ptr*")))
		_k_pipe_ptr_end = .;
	} GROUP_LINK_IN(RAM)

	SECTION_PROLOGUE(_k_mem_map_ptr, (OPTIONAL),)
	{
		_k_mem_map_ptr_start = .;
			*(._k_mem_map_ptr.public.*)
			*(._k_mem_map_ptr.private.*)
		KEEP(*(SORT_BY_NAME("._k_mem_map_ptr*")))
		_k_mem_map_ptr_end = .;
	} GROUP_LINK_IN(RAM)

	SECTION_PROLOGUE(_k_event_list, (OPTIONAL),)
	{
		_k_event_list_start = .;
			*(._k_event_list.event.*)
		KEEP(*(SORT_BY_NAME("._k_event_list*")))
		_k_event_list_end = .;
	} GROUP_LINK_IN(RAM)

	__data_ram_end = .;

	SECTION_PROLOGUE(_BSS_SECTION_NAME, (NOLOAD OPTIONAL),)
	{
	/*
	 * For performance, BSS section is forced to be both 4 byte aligned and
	 * a multiple of 4 bytes.
	 */

	. = ALIGN(4);

	__bss_start = .;

	*(.bss)
	*(".bss.*")
	COMMON_SYMBOLS
	/*
	 * As memory is cleared in words only, it is simpler to ensure the BSS
	 * section ends on a 4 byte boundary. This wastes a maximum of 3 bytes.
	 */
	. = ALIGN(4);
	__bss_end = .;
	KEXEC_PGALIGN_PAD(MMU_PAGE_SIZE)
	} GROUP_LINK_IN(RAM)
#ifdef CONFIG_XIP
	/*
	 * Ensure linker keeps sections in correct order, despite the fact
	 * the previous section specified a load address and this no-load
	 * section doesn't.
	 */
	  GROUP_FOLLOWS_AT(RAM)
#endif

	SECTION_PROLOGUE(_NOINIT_SECTION_NAME, (NOLOAD OPTIONAL),)
	{
	/*
	 * This section is used for non-intialized objects that
	 * will not be cleared during the boot process.
	 */
	*(.noinit)
	*(".noinit.*")

	INT_STUB_NOINIT
	} GROUP_LINK_IN(RAM)

	/* Define linker symbols */
	_image_ram_end = .;
	_end = .; /* end of image */

	. = ALIGN(MMU_PAGE_SIZE);

	__bss_num_words	= (__bss_end - __bss_start) >> 2;

	GROUP_END(RAM)

	/* static interrupts */
	SECTION_PROLOGUE(intList, (OPTIONAL),)
	{
	KEEP(*(.spurIsr))
	KEEP(*(.spurNoErrIsr))
	__INT_LIST_START__ = .;
	LONG((__INT_LIST_END__ - __INT_LIST_START__) / __ISR_LIST_SIZEOF)
	KEEP(*(.intList))
	__INT_LIST_END__ = .;
	} > IDT_LIST

	/* verify we don't have rogue .init_<something> initlevel sections */
	SECTION_PROLOGUE(initlevel_error, (OPTIONAL), )
	{
		DEVICE_INIT_UNDEFINED_SECTION()
	}
	ASSERT(SIZEOF(initlevel_error) == 0, "Undefined initialization levels used.")

	}

#ifdef CONFIG_XIP
/*
 * Round up number of words for DATA section to ensure that XIP copies the
 * entire data section. XIP copy is done in words only, so there may be up
 * to 3 extra bytes copied in next section (BSS). At run time, the XIP copy
 * is done first followed by clearing the BSS section.
 */
__data_size = (__data_ram_end - __data_ram_start);
__data_num_words = (__data_size + 3) >> 2;
__ram_phys_end = PHYS_RAM_ADDR + LENGTH(RAM);
#endif

ASSERT ((__data_rom_start + __data_size) <= (PHYS_LOAD_ADDR + FLASH_SIZE),"Binary too big to fit in flash partition");

/* start adding bsp specific linker sections here */

/* no sections should appear after linker-epilog.h */
#include <arch/x86/linker-epilog.h>
