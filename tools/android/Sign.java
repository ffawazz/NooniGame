import com.android.apksig.ApkSigner;
import com.android.apksig.ApkVerifier;
import java.io.File;
import java.io.FileInputStream;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.List;

/** Minimal apksigner: `sign ks storepass alias keypass in out` or `verify apk`. */
public class Sign {
    public static void main(String[] a) throws Exception {
        if (a[0].equals("verify")) {
            ApkVerifier.Result r = new ApkVerifier.Builder(new File(a[1])).setMinCheckedPlatformVersion(24).build().verify();
            System.out.println("Verified: " + r.isVerified() + "  v1=" + r.isVerifiedUsingV1Scheme() + " v2=" + r.isVerifiedUsingV2Scheme());
            for (ApkVerifier.IssueWithParams e : r.getErrors()) System.out.println("ERROR: " + e);
            System.exit(r.isVerified() ? 0 : 1);
        }
        KeyStore ks = KeyStore.getInstance(KeyStore.getDefaultType());
        try (FileInputStream in = new FileInputStream(a[1])) { ks.load(in, a[2].toCharArray()); }
        PrivateKey key = (PrivateKey) ks.getKey(a[3], a[4].toCharArray());
        List<X509Certificate> chain = new ArrayList<>();
        for (java.security.cert.Certificate c : ks.getCertificateChain(a[3])) chain.add((X509Certificate) c);
        ApkSigner.SignerConfig cfg = new ApkSigner.SignerConfig.Builder("CERT", key, chain).build();
        List<ApkSigner.SignerConfig> cfgs = new ArrayList<>();
        cfgs.add(cfg);
        new ApkSigner.Builder(cfgs)
            .setInputApk(new File(a[5])).setOutputApk(new File(a[6]))
            .setMinSdkVersion(24).setV1SigningEnabled(false).setV2SigningEnabled(true)
            .build().sign();
        System.out.println("Signed " + a[6]);
    }
}
