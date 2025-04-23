"""
Text normalization and cleaning utilities for CSM-1B TTS system.
Handles common issues like contractions, numbers, and special characters.
"""
import re
import logging

logger = logging.getLogger(__name__)

class TextNormalizer:
    """Text normalization utilities for TTS."""
    
    # Common English contractions mapping
    CONTRACTIONS = {
        "don't": "dont",
        "won't": "wont",
        "can't": "cant",
        "isn't": "isnt",
        "he's": "hes",
        "she's": "shes",
        "they're": "theyre",
        "we're": "were",
        "you're": "youre",
        "that's": "thats",
        "it's": "its",
        "what's": "whats",
        "let's": "lets",
        "who's": "whos",
        "how's": "hows",
        "where's": "wheres",
        "there's": "theres",
        "wouldn't": "wouldnt",
        "shouldn't": "shouldnt",
        "couldn't": "couldnt",
        "hasn't": "hasnt",
        "haven't": "havent",
        "hadn't": "hadnt",
        "didn't": "didnt",
        "i'm": "im",
        "i've": "ive",
        "i'd": "id",
        "i'll": "ill",
        "you've": "youve",
        "you'll": "youll",
        "you'd": "youd",
        "we've": "weve",
        "we'll": "well",
        "we'd": "wed",
        "they've": "theyve",
        "they'll": "theyll",
        "they'd": "theyd",
        "aren't": "arent",
        "weren't": "werent",
        "wasn't": "wasnt",
    }
    
    # Common abbreviations to expand
    ABBREVIATIONS = {
        "Mr.": "Mister",
        "Mrs.": "Misses",
        "Dr.": "Doctor",
        "Prof.": "Professor",
        "St.": "Street",
        "Rd.": "Road",
        "Ave.": "Avenue",
        "vs.": "versus",
        "etc.": "etcetera",
        "e.g.": "for example",
        "i.e.": "that is",
        "approx.": "approximately",
    }
    
    # Simple number words for common numbers
    NUMBER_WORDS = {
        "0": "zero",
        "1": "one",
        "2": "two",
        "3": "three",
        "4": "four",
        "5": "five",
        "6": "six",
        "7": "seven",
        "8": "eight",
        "9": "nine",
        "10": "ten",
        "11": "eleven",
        "12": "twelve",
        "13": "thirteen",
        "14": "fourteen",
        "15": "fifteen",
        "16": "sixteen",
        "17": "seventeen",
        "18": "eighteen",
        "19": "nineteen",
        "20": "twenty",
        "30": "thirty",
        "40": "forty",
        "50": "fifty",
        "60": "sixty",
        "70": "seventy",
        "80": "eighty",
        "90": "ninety",
        "100": "one hundred",
        "1000": "one thousand",
        "1000000": "one million",
        "1000000000": "one billion",
    }
    
    @classmethod
    def normalize_text(cls, text: str) -> str:
        """
        Normalize text for TTS: handle contractions, punctuation, and special cases.
        
        Args:
            text: Input text to normalize
            
        Returns:
            Normalized text ready for TTS
        """
        if not text:
            return text
            
        # Log original text for debugging
        logger.debug(f"Normalizing text: '{text}'")
        
        # Remove voice instructions in square brackets
        text = re.sub(r'\[.*?\]', '', text)
        
        # Handle contractions - preserving case sensitivity
        for contraction, replacement in cls.CONTRACTIONS.items():
            # Case insensitive replacement
            text = re.sub(r'\b' + re.escape(contraction) + r'\b', replacement, text, flags=re.IGNORECASE)
        
        # Expand common abbreviations
        for abbr, expanded in cls.ABBREVIATIONS.items():
            text = text.replace(abbr, expanded)
        
        # Handle numbers - only convert standalone numbers
        def replace_number(match):
            number = match.group(0)
            if number in cls.NUMBER_WORDS:
                return cls.NUMBER_WORDS[number]
            return number
            
        text = re.sub(r'\b\d+\b', replace_number, text)
        
        # Replace problematic symbols
        text = text.replace("&", " and ")
        text = text.replace("%", " percent ")
        text = text.replace("@", " at ")
        text = text.replace("#", " number ")
        text = text.replace("$", " dollar ")
        text = text.replace("€", " euro ")
        text = text.replace("£", " pound ")
        text = text.replace("¥", " yen ")
        
        # Handle dates in MM/DD/YYYY format
        text = re.sub(r'\b(\d{1,2})/(\d{1,2})/(\d{4})\b', r'\1 \2 \3', text)
        
        # Fix excessive spaces
        text = re.sub(r'\s+', ' ', text).strip()
        
        # Ensure sentence ends with punctuation
        if not text[-1] in ['.', '!', '?', ';', ':', ',']:
            text = text + '.'
            
        logger.debug(f"Normalized text: '{text}'")
        return text
    
    @classmethod
    def split_into_sentences(cls, text: str) -> list:
        """
        Split text into sentences for better TTS performance.
        
        Args:
            text: Input text to split
            
        Returns:
            List of sentences
        """
        # Normalize first
        text = cls.normalize_text(text)
        
        # Split on sentence boundaries
        sentences = re.split(r'(?<=[.!?])\s+', text)
        
        # Remove empty sentences
        sentences = [s for s in sentences if s.strip()]
        
        return sentences

def clean_text_for_tts(text: str) -> str:
    """Clean and normalize text for TTS processing."""
    return TextNormalizer.normalize_text(text)