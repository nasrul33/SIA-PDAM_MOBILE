# Aturan R8/ProGuard untuk build rilis.
# Flutter & sebagian besar plugin (dio, sqflite, image_picker, connectivity_plus,
# flutter_secure_storage) sudah membawa consumer-rules sendiri, jadi file ini
# umumnya cukup minimal. Tambahkan keep di sini bila ada kelas yang ter-strip.

# Jaga anotasi & atribut yang sering dibutuhkan refleksi/serialisasi.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
