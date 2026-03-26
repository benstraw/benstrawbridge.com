import { library } from '@fortawesome/fontawesome-svg-core'
import Alpine from '@alpinejs/csp'
import {
  faAnchor,
  faArrowLeft,
  faArrowRight,
  faArrowUpRightFromSquare,
  faBasketball,
  faBreadSlice,
  faBurst,
  faCarTunnel,
  faCarrot,
  faCashRegister,
  faCloudMeatball,
  faCodeCompare,
  faCodeMerge,
  faCog,
  faCoins,
  faCompass,
  faCruzeiroSign,
  faDiagramProject,
  faDice,
  faDog,
  faDragon,
  faDrum,
  faEnvelope,
  faFingerprint,
  faFishFins,
  faFootball,
  faFutbol,
  faHeadphones,
  faHeartPulse,
  faHockeyPuck,
  faImages,
  faJedi,
  faKitchenSet,
  faLink,
  faMagnifyingGlass,
  faMap,
  faMinimize,
  faMobileScreen,
  faMountain,
  faPalette,
  faPaw,
  faPersonHiking,
  faPrint,
  faRobot,
  faRotate,
  faScissors,
  faTableCells,
  faTag,
  faTerminal,
  faTrophy,
  faWheatAwn,
} from '@fortawesome/free-solid-svg-icons'
import {
  faCalendar as farCalendar,
  faCopyright as farCopyright,
  faFolderOpen as farFolderOpen,
} from '@fortawesome/free-regular-svg-icons'
import {
  faLinkedin,
  faPagelines,
} from '@fortawesome/free-brands-svg-icons'

// Site-specific icons that are referenced in benstrawbridge.com content and layouts.
library.add(
  faAnchor,
  faArrowLeft,
  faArrowRight,
  faArrowUpRightFromSquare,
  faBasketball,
  faBreadSlice,
  faBurst,
  faCarTunnel,
  faCarrot,
  faCashRegister,
  faCloudMeatball,
  faCodeCompare,
  faCodeMerge,
  faCog,
  faCoins,
  faCompass,
  faCruzeiroSign,
  faDiagramProject,
  faDice,
  faDog,
  faDragon,
  faDrum,
  faEnvelope,
  faFingerprint,
  faFishFins,
  faFootball,
  faFutbol,
  faHeadphones,
  faHeartPulse,
  faHockeyPuck,
  faImages,
  faJedi,
  faKitchenSet,
  faLink,
  faLinkedin,
  faMagnifyingGlass,
  faMap,
  faMinimize,
  faMobileScreen,
  faMountain,
  faPagelines,
  faPalette,
  faPaw,
  faPersonHiking,
  faPrint,
  faRobot,
  faRotate,
  farCalendar,
  farCopyright,
  farFolderOpen,
  faScissors,
  faTableCells,
  faTag,
  faTerminal,
  faTrophy,
  faWheatAwn,
)

const registerLinksPage = (alpine) => alpine.data('linksPage', () => ({
  search: '',
  selectedTag: '',
  links: [],
  init() {
    try {
      const rawLinks = this.$el.dataset.linkData || '[]'
      const parsedLinks = JSON.parse(rawLinks)
      this.links = Array.isArray(parsedLinks) ? parsedLinks : []
    } catch (error) {
      console.error('Error parsing link data:', error)
      this.links = []
    }
    const params = new URLSearchParams(window.location.search)
    this.search = params.get('search') || ''
    this.selectedTag = params.get('tag') || ''
    if (this.selectedTag && !this.availableTags.includes(this.selectedTag)) {
      this.selectedTag = ''
    }
  },
  get availableTags() {
    return [...new Set(this.links.flatMap((link) => link.tags || []))].sort()
  },
  get filteredLinks() {
    const q = this.search.toLowerCase().trim()
    return this.links.filter((link) => {
      if (this.selectedTag && !(link.tags || []).includes(this.selectedTag)) return false
      if (!q) return true
      return (
        (link.title || '').toLowerCase().includes(q) ||
        (link.description || '').toLowerCase().includes(q)
      )
    })
  },
}))

registerLinksPage(Alpine)
if (window.Alpine && window.Alpine !== Alpine) {
  registerLinksPage(window.Alpine)
}

// Check if the changeBackgroundImage function exists before calling it
if (typeof changeBackgroundImage === "function") {
  changeBackgroundImage([
    "https://lh3.googleusercontent.com/pw/ABLVV84PckiqmIJNE5iB3BI_vV-grDSeDQfjyyLolAE1_t_No1Z_IlzgI9UJ5rvabL5U-gnT_v7_S07qkzF-ucjzEJT5kLFwtUaLwfebH-2R4GiUDEIukIfOHaEVi_JECfmXOyDDAsb3zwNfaZN78b2lXbwxgg=w613-h1088-s-no-gm?authuser=0",
    "https://lh3.googleusercontent.com/pw/ABLVV854B1XWYwZtzSIxhizEmGnrW1jgdyI0P9gQ942oI715M_4mGXWUIniRb5p5xedTx9WS4_nGIB_IOdK9ypRNDDPStmqwpwMA_RdC6NwtolzRe1uN0d6_NIISimDXWuiuM91pzNh4RMtpyUkybPcg3hWHxw=w613-h1088-s-no-gm?authuser=0",
    "https://lh3.googleusercontent.com/pw/ABLVV86h_0kvKZ-eRI1WJhUOpIRk0elQ0rypGEWcQJnHX5QgLBYY3KqKwCrVn7hVIhKZoCymxjg_P8tHbMaPqg2iY-EeODHvcG4hv1VTVf1dyPCoEhm9qP1as1EEgK_wVJ6oq4cuO548n4i1CoQzO3FncLdm6Q=w1155-h650-s-no-gm?authuser=0",
    "https://lh3.googleusercontent.com/pw/ABLVV872UJW6LsZ3ecRRu0Q97APztiiW2gjxooi-fJSMaosj_KCMLrWeoTnkZwXJGfEd52lZHSY78vZUGlqdZ3hVAN0WQ_Ogw2fW5e2z6f_yIs9ZXZPB3XroeCNaPfFDxpieIt9Y4gZAaF5yeU175SY-nK4P8g=w612-h1088-s-no-gm?authuser=0",
    "https://lh3.googleusercontent.com/pw/ABLVV86tz5bkwmjiMkPBtuWfrpuoIjW_h3ZLbiQKIb4XhWe0JTTKxrPpNa9diFj-PB0UYixQl7bTACVoj-pdHGQI68LZCgM7lBbHVlCB8afJ_k_F0hotPQDRIrMdlS_ZY6t7HDinj_qivFvabsLVubPmT5wE_g=w1155-h650-s-no-gm?authuser=0",
    "https://lh3.googleusercontent.com/pw/ABLVV875N7UIlnDhom-ggcxRAYKB4zGp4tdJlfg92qBNhdq2Ne761IbqOGpIONrThF4OLWnoim_bklMle8y4YRQ_m8ir6Lpemve2p0FRd14wAL2zjHlSZY_yt5bnizUyWuS5lG3vPuCMjZRUxW1-w2-_IPZ8Hw=w1155-h650-s-no-gm?authuser=0",
  ]);
}
